# Resources are split across dedicated files:
#   cloud_sql.tf — Cloud SQL instance, database, user
#   iam.tf       — Service accounts and IAM bindings
#   secrets.tf   — Secret Manager secrets for DB connection
#   apis.tf      — GCP API enablement
#
# Conexion Cloud Run -> Cloud SQL: Auth Proxy nativo (sin VPC Connector).
# Ver specs/01_plan_infraestructura.md para detalle de la decision.
