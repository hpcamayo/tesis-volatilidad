# Tesis: Superficies de volatilidad implicita

Repositorio de trabajo para el analisis funcional y la reescritura de tesis sobre superficies de volatilidad implicita en mercados de divisas.

## Contenido principal

- `tesis_volatilidad_analysis_final.R`: pipeline principal de analisis y backtesting.
- `vols3.xlsx`: base de datos de superficies de volatilidad implicita.
- `aggregate_tesis_outputs.R`: agregacion de resultados por par de divisas.
- `analyze_fpca_scores.R`: diagnosticos y visualizaciones de puntajes FPCA.
- `tesis_rewrite_final.tex`: borrador LaTeX reescrito con el nuevo encuadre empirico.
- `tesis_rewrite_final.html`: vista previa HTML generada desde el borrador LaTeX.
- `tesis_outputs/`: tablas, figuras y objetos `.rds` generados por la corrida final.

## Reproducibilidad

Ejecutar el pipeline completo:

```sh
Rscript tesis_volatilidad_analysis_final.R
```

Regenerar tablas agregadas:

```sh
Rscript aggregate_tesis_outputs.R
Rscript analyze_fpca_scores.R
```

## Resultado empirico central

La FPCA representa las superficies de manera parsimoniosa, pero los modelos dinamicos sobre puntajes FPCA no superan a la persistencia cruda bajo RMSE sobre la malla observada en la corrida verificada.
