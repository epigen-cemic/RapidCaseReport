# RumorForm WP1.1 - Formulario de Reporte Rápido de Casos Sospechosos

**Versión:** v20250624  
**Despliegue:** [https://epigen.shinyapps.io/rumorform_v1.10F/](https://epigen.shinyapps.io/rumorform_v1.10F/)

## Descripción

Esta aplicación Shiny forma parte del Work Package WS5 (WP1.1) del proyecto PPT-UK – Argentina. Permite el reporte estructurado y rápido de eventos de salud sospechosos ("rumores"), recopilando datos individuales, clínicos y diagnósticos.

## Características
- Generación automática de ID único por formulario
- Autocompletado de país/provincia/localidad usando GeoNames API
- Campos de codificación HPO e ICD-10
- Descarga en CSV de todos los formularios registrados
- Imagen de fondo institucional (SVG CEMIC)

## Cómo Ejecutarla Localmente

### Requisitos
- R (>= 4.2.0)
- RStudio
- Paquetes necesarios:
  ```r
  install.packages(c("shiny", "dplyr", "uuid", "httr", "jsonlite", "rsconnect"))
  ```
- Versión de Rcpp compatible:
  ```r
  install.packages("remotes")
  remotes::install_version("Rcpp", version = "1.0.11")
  ```

### Estructura del Proyecto
```
RumorForm_v20250624/
├── app.R
└── www/
    └── Imagen_FondoPPT_CEMIC.svg
```

### Ejecutar la App
```r
setwd("ruta/a/RumorForm_v1.10F")
shiny::runApp()
```

## Publicar en shinyapps.io
1. Crear cuenta gratuita en [https://www.shinyapps.io](https://www.shinyapps.io)
2. Configurar `rsconnect`:
   ```r
   install.packages("rsconnect")
   rsconnect::setAccountInfo(name='usuario', token='token', secret='clave')
   ```
3. Subir la app:
   ```r
   rsconnect::deployApp()
   ```

## Demo en Línea
🌐 [https://epigen.shinyapps.io/rumorform_v1.10F/](https://epigen.shinyapps.io/rumorform_v1.10F/)

## Contacto
**Proyecto:** PPT-UK – Argentina WS5  
**Institution - Delivery Partner:** CEMIC
