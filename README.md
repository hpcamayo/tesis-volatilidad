# Tesis: Superficies de volatilidad implicita

Repositorio de trabajo para el analisis funcional y la reescritura de tesis sobre superficies de volatilidad implicita en mercados de divisas.

## Contenido principal

- `tesis_volatilidad_analysis_final.R`: pipeline principal de analisis y backtesting.
- `vols3.xlsx`: base de datos de superficies de volatilidad implicita.
- `aggregate_tesis_outputs.R`: agregacion de resultados por par de divisas.
- `aggregate_loss_robustness.R`: agregacion de robustez por funcion de perdida.
- `analyze_fpca_scores.R`: diagnosticos y visualizaciones de puntajes FPCA.
- `tesis_basis_robustness.R`: robustez a la especificacion de base B-spline.
- `tesis_draft_detallado.tex`: borrador LaTeX actualizado con resultados rolling FPCA y robustez.
- `tesis_rewrite_final.tex`: borrador LaTeX reescrito con el nuevo encuadre empirico.
- `tesis_rewrite_final.html`: vista previa HTML generada desde el borrador LaTeX.
- `tesis_outputs/`: tablas, figuras y objetos `.rds` generados por la corrida final.

## Reproducibilidad

Ejecutar el pipeline principal para un par:

```sh
MONEDA_WORK_OVERRIDE=usdpen RUN_ALL_MONEDAS_OVERRIDE=FALSE Rscript tesis_volatilidad_analysis_final.R
```

Regenerar tablas agregadas:

```sh
Rscript aggregate_tesis_outputs.R
Rscript aggregate_loss_robustness.R
Rscript analyze_fpca_scores.R
```

Ejecutar solo el diagnostico rolling FPCA para un par:

```sh
MONEDA_WORK_OVERRIDE=usdpen RUN_ALL_MONEDAS_OVERRIDE=FALSE STOP_AFTER_ROLLING_FPCA=TRUE Rscript tesis_volatilidad_analysis_final.R
```

Ejecutar robustez de bases:

```sh
BASIS_ROBUSTNESS_MONEDAS='usdpen,usdcop,usdclp,usdbrl,usdars,usdmxn,eurusd,usdzar' \
BASIS_ROBUSTNESS_BASIS_IDS='base_4x8,coarse_4x6,rich_5x10' \
BASIS_ROBUSTNESS_MAX_K0='15' \
BASIS_ROBUSTNESS_INCLUDE_KERNEL='TRUE' \
Rscript tesis_basis_robustness.R
```

## Resultado empirico central

La FPCA representa las superficies de manera parsimoniosa, pero los modelos dinamicos sobre puntajes FPCA no superan sistematicamente a la persistencia cruda. En la especificacion principal, PM domina bajo RMSE, MAE y ponderaciones por tenor; la base B-spline rica introduce excepciones locales, pero no cambia la conclusion general.
