# Construye el mapa image_tags desde variables individuales por servicio.
# Cada variable vive en su propio *.auto.tfvars — sin conflictos de merge.
locals {
  image_tags = {
    "accounting-fuel-savings" = var.image_tag_accounting_fuel_savings
    "accounting-invoice"      = var.image_tag_accounting_invoice
    "aircraft-discrepancies"  = var.image_tag_aircraft_discrepancies
    "aircraft-logged-flights" = var.image_tag_aircraft_logged_flights
    "aircraft-utilization"    = var.image_tag_aircraft_utilization
    "sales-productivity"      = var.image_tag_sales_productivity
    "trip-finances"           = var.image_tag_trip_finances
    "session-service-api"     = var.image_tag_session_service_api
  }
}
