# Resultados de robustez por especificacion de base

Se ejecuto `tesis_basis_robustness.R` para los 8 pares, 3 horizontes y 3 bases B-spline tensoriales:

| Base | K_delta | K_tenor | Lectura |
|---|---:|---:|---|
| `base_4x8` | 4 | 8 | Especificacion principal |
| `coarse_4x6` | 4 | 6 | Base mas parsimoniosa |
| `rich_5x10` | 5 | 10 | Base mas flexible |

El archivo `basis_robustness_status.csv` reporta 24 de 24 bloques con estado `OK`.

## Dominancia de PM por base y perdida

| Base | Perdida | Casos PM | Total | Proporcion PM |
|---|---|---:|---:|---:|
| `base_4x8` | MAE | 24 | 24 | 100.0% |
| `base_4x8` | RMSE | 24 | 24 | 100.0% |
| `base_4x8` | WRMSE largo | 24 | 24 | 100.0% |
| `base_4x8` | WRMSE corto | 23 | 24 | 95.8% |
| `coarse_4x6` | MAE | 24 | 24 | 100.0% |
| `coarse_4x6` | RMSE | 24 | 24 | 100.0% |
| `coarse_4x6` | WRMSE largo | 24 | 24 | 100.0% |
| `coarse_4x6` | WRMSE corto | 23 | 24 | 95.8% |
| `rich_5x10` | MAE | 23 | 24 | 95.8% |
| `rich_5x10` | RMSE | 18 | 24 | 75.0% |
| `rich_5x10` | WRMSE largo | 23 | 24 | 95.8% |
| `rich_5x10` | WRMSE corto | 16 | 24 | 66.7% |

## Lectura thesis-ready

La base principal y la base parsimoniosa preservan la conclusion central: PM domina todas las celdas de RMSE, MAE y WRMSE largo, y solo pierde una celda de WRMSE corto, USD/COP a h=10, frente a PA. Esta excepcion no favorece a un modelo dinamico, sino a una persistencia suavizada.

La base rica `rich_5x10` produce mas excepciones. PM sigue dominando MAE y WRMSE largo casi por completo, pero bajo RMSE gana 18 de 24 casos y bajo WRMSE corto gana 16 de 24. Las excepciones se concentran en horizontes h=5 y h=10, y aparecen en PA, ARHinc y KernelARH segun el par y la perdida.

La conclusion no cambia de signo, pero si se vuelve mas precisa. La evidencia no permite afirmar que los modelos dinamicos superen sistematicamente a PM. Lo que muestra la base rica es que una representacion mas flexible puede reducir el costo de reconstruccion en ciertas celdas locales, especialmente cuando se ponderan mas los vencimientos cortos. Esto debe presentarse como robustez parcial con excepciones informativas, no como una victoria general de los modelos dinamicos.

## Excepciones no PM

Las excepciones no PM en la robustez de bases son 18 de 288 combinaciones par-horizonte-base-perdida. Las mas importantes son:

| Par | Base | h | Modelo | Perdida | Valor | PM | Mejora vs PM |
|---|---|---:|---|---|---:|---:|---:|
| USD/COP | `base_4x8` | 10 | PA | WRMSE corto | 0.930 | 0.936 | 0.6% |
| USD/COP | `coarse_4x6` | 10 | PA | WRMSE corto | 0.932 | 0.936 | 0.4% |
| USD/COP | `rich_5x10` | 10 | KernelARH | WRMSE corto | 0.804 | 0.936 | 14.1% |
| USD/COP | `rich_5x10` | 10 | PA | RMSE | 0.586 | 0.644 | 9.1% |
| EUR/USD | `rich_5x10` | 5 | ARHinc | RMSE | 0.369 | 0.374 | 1.3% |
| USD/BRL | `rich_5x10` | 10 | PA | RMSE | 0.761 | 0.768 | 0.8% |
| USD/MXN | `rich_5x10` | 10 | PA | RMSE | 0.416 | 0.425 | 2.0% |
| USD/ZAR | `rich_5x10` | 10 | PA | RMSE | 0.546 | 0.555 | 1.6% |

## Archivos

```text
tesis_outputs/robustez_bases/basis_robustness_status.csv
tesis_outputs/robustez_bases/tabla_basis_losses_long.csv
tesis_outputs/robustez_bases/tabla_basis_robust_loss.csv
tesis_outputs/robustez_bases/tabla_basis_best_by_loss.csv
tesis_outputs/robustez_bases/tabla_basis_pm_dominance.csv
tesis_outputs/robustez_bases/tabla_basis_tuning_k0.csv
```
