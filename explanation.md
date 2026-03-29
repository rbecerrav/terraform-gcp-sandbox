# Cómo funciona todo este setup

## El problema que resolvemos

Queremos que GitHub pueda ejecutar comandos de Terraform que modifiquen recursos en GCP.
Para eso GitHub necesita **credenciales** para hablar con GCP.

La forma insegura sería crear una clave JSON del Service Account y pegarla como secret en GitHub.
El problema: esas claves no expiran, si se filtran son un riesgo enorme.

La forma segura (la que usamos) es **Workload Identity Federation**: GitHub obtiene un token temporal
de GCP que dura máximo 1 hora, sin ninguna clave almacenada en ningún lado.

---

## Las piezas del sistema

```
Tu computadora (código Terraform)
        │
        │  git push / PR
        ▼
  GitHub (repositorio)
        │
        │  detecta evento (PR abierto, merge a main, etc.)
        ▼
  GitHub Actions (servidor CI/CD de GitHub)
        │
        │  necesita hablar con GCP → pide token
        ▼
  GCP: Workload Identity Federation
        │  verifica: "¿esto viene realmente de rbecerrav/terraform-gcp-sandbox?"
        │  si sí → emite token temporal (1 hora)
        ▼
  Service Account (github-actions-sa)
        │  tiene permisos para crear/modificar recursos en GCP
        ▼
  Terraform se ejecuta y aplica los cambios en GCP
```

---

## Qué es cada cosa

### GitHub Actions
Es el sistema de CI/CD integrado en GitHub. Funciona con archivos YAML que viven en
`.github/workflows/`. Cada archivo define un "workflow" que se dispara ante ciertos eventos.

Nosotros creamos 3 workflows:

| Archivo | Cuándo se ejecuta | Qué hace |
|---|---|---|
| `terraform-plan.yml` | Cuando abres o actualizas un PR | Corre `terraform plan` y pega el resultado como comentario en el PR |
| `terraform-apply.yml` | Cuando se mergea un PR a `main` | Corre `terraform apply` — despliega los cambios en GCP |
| `terraform-destroy.yml` | Manual o por cron | Corre `terraform destroy` — elimina todos los recursos |

### GitHub Secrets
Son variables de entorno encriptadas que GitHub Actions puede leer durante la ejecución
pero que nadie puede ver una vez guardadas (ni por UI ni por API).

Guardamos 3 secrets:
- `GCP_PROJECT_ID` — el ID de tu proyecto GCP
- `WIF_PROVIDER` — la "dirección" del pool de identidad en GCP
- `WIF_SERVICE_ACCOUNT` — el email del service account que ejecutará Terraform

### Branch Protection Rules
Reglas que protegen la rama `main` de cambios directos. Configuramos:
- Nadie puede hacer `git push` directo a `main` (ni tú como admin)
- Todo cambio debe entrar por un Pull Request
- El PR necesita que pase el check de `Terraform Plan` (el workflow)
- El PR necesita tu aprobación si lo abre tu compañero
- Si hay nuevos commits después de tu aprobación, se resetea y necesita nueva aprobación

### CODEOWNERS
El archivo `.github/CODEOWNERS` le dice a GitHub quién es el dueño del código.
Con `* @rbecerrav` declaras que tú eres dueño de todo.
GitHub te asigna automáticamente como reviewer requerido en cada PR que abra tu compañero.

---

## Workload Identity Federation — cómo funciona en detalle

### Los componentes que creamos en GCP

**1. Service Account** (`github-actions-sa`)
Es una "cuenta de robot" en GCP. No es una persona, es una identidad que tiene permisos
para crear y modificar recursos. Le dimos:
- `roles/editor` — puede crear/modificar casi cualquier recurso
- `roles/storage.admin` — puede leer y escribir el bucket donde vive el tfstate

**2. Workload Identity Pool** (`github-actions-pool`)
Es una "sala de espera" en GCP donde llegan identidades externas (de fuera de GCP)
a pedir acceso. Piénsalo como el portero de un edificio.

**3. OIDC Provider** (`github-actions-provider`)
Le dice al pool "confía en tokens que vengan de `token.actions.githubusercontent.com`"
(que es el servidor de GitHub). También configuramos una condición:
```
assertion.repository == 'rbecerrav/terraform-gcp-sandbox'
```
Esto significa que aunque alguien más tenga otro repo en GitHub, no puede usar este pool.
Solo tu repo específico puede obtener tokens.

### El flujo paso a paso cuando corre un workflow

```
1. GitHub Actions inicia un job

2. El step "Authenticate to Google Cloud" llama a google-github-actions/auth@v2

3. Ese action le pide a GitHub un OIDC token (JWT firmado por GitHub)
   El token contiene: quién eres, de qué repo, de qué branch, etc.

4. Ese JWT se envía a GCP: "quiero acceder como github-actions-sa, aquí está mi prueba"

5. GCP verifica:
   - ¿El JWT está firmado por token.actions.githubusercontent.com? ✓
   - ¿El repository es rbecerrav/terraform-gcp-sandbox? ✓
   - ¿Este repo tiene permiso para impersonar github-actions-sa? ✓

6. GCP devuelve un access token temporal (dura 1 hora)

7. Terraform usa ese token para hacer cambios en GCP

8. Después de 1 hora el token expira automáticamente
```

---

## El flujo completo del día a día

### Cuando tu compañero hace un cambio

```
1. Tu compañero crea una branch:
   git checkout -b feature/nuevo-bucket

2. Hace cambios en main.tf y sube:
   git push origin feature/nuevo-bucket

3. Abre un Pull Request en GitHub hacia main

4. GitHub Actions ejecuta terraform-plan.yml automáticamente:
   - Se autentica en GCP via WIF
   - Corre terraform plan
   - Pega el resultado como comentario en el PR
   (así tú puedes ver exactamente qué va a crear/modificar/destruir)

5. Tú revisas el plan en el comentario + el código

6. Si está bien, apruebas el PR

7. Tu compañero (o tú) hace merge

8. GitHub Actions ejecuta terraform-apply.yml:
   - Se autentica en GCP via WIF
   - Corre terraform apply
   - Los recursos se crean/modifican en GCP
```

### Cuando quieres destruir todo

```
GitHub → pestaña Actions → Terraform Destroy → Run workflow → escribes "destroy" → Run

GitHub Actions ejecuta terraform-destroy.yml:
   - Se autentica en GCP via WIF
   - Corre terraform destroy
   - Todos los recursos se eliminan de GCP
```

---

## El estado de Terraform (tfstate)

Terraform necesita recordar qué recursos ya creó para saber qué cambiar o destruir.
Eso lo guarda en un archivo llamado `terraform.tfstate`.

Lo guardamos en un bucket de GCS (ya existía):
```
bucket: tfstate-7ceba286-c3bb-4d79
prefix: bucket-state
```

Así tanto tú localmente como GitHub Actions trabajan contra el mismo estado,
y no hay conflictos de "yo creo que existe / yo creo que no existe".

---

## Resumen de archivos creados

```
.github/
  CODEOWNERS                  → tú eres reviewer requerido en todos los PRs
  workflows/
    terraform-plan.yml        → corre plan en cada PR
    terraform-apply.yml       → corre apply al mergear a main
    terraform-destroy.yml     → destruye todo (manual o por cron)

scripts/
  setup-wif.sh                → script que ejecutamos para crear todo en GCP

versions.tf                   → versión de Terraform, configuración del backend GCS
providers.tf                  → configuración del provider de GCP
variables.tf                  → variables (project_id, region)
main.tf                       → aquí van tus recursos GCP
outputs.tf                    → valores que Terraform imprime al terminar
```
