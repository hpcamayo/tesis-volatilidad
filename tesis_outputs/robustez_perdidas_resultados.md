# Resultados de robustez por funcion de perdida

Se ejecuto la robustez por funcion de perdida para los 8 pares y 3 horizontes usando la especificacion principal `base_4x8`, con los `TRAIN_SIZE` y `K0` de la corrida principal.

## Perdidas evaluadas

- `RMSE_med`
- `MAE_med`
- `WRMSE_short_med`: RMSE ponderado hacia vencimientos cortos.
- `WRMSE_long_med`: RMSE ponderado hacia vencimientos largos.

En total se evaluaron:

```text
8 pares x 3 horizontes x 4 funciones de perdida = 96 comparaciones
```

## Resultado principal

La conclusion principal se mantiene con mucha fuerza:

```text
PM gana 95 de 96 comparaciones.
```

La unica excepcion es:

| Par | h | Funcion de perdida | Mejor modelo |
|---|---:|---|---|
| USD/COP | 10 | WRMSE_short_med | PA |

Esta excepcion no favorece a un modelo dinamico. `PA` es persistencia de la superficie ajustada por base, por lo que sigue siendo una forma de persistencia. En consecuencia, bajo estas perdidas alternativas no aparece ningun caso en el que `VAR1`, `ARHinc` o `KernelARH` sea el mejor modelo.

## Dominancia por perdida

| Perdida | Casos PM | Total | Lectura |
|---|---:|---:|---|
| RMSE_med | 24 | 24 | Igual que la metrica principal |
| MAE_med | 24 | 24 | Robusto a usar error absoluto |
| WRMSE_long_med | 24 | 24 | Robusto cuando se enfatizan tenores largos |
| WRMSE_short_med | 23 | 24 | Una excepcion PA en USD/COP h=10 |

## Interpretacion

La robustez por funcion de perdida refuerza el resultado central de la tesis. La dominancia de la persistencia no es un artefacto de usar RMSE. Tambien aparece bajo MAE y bajo metricas que cambian la importancia relativa de los vencimientos cortos y largos.

La unica excepcion, USD/COP a horizonte 10 bajo ponderacion de tenores cortos, favorece a `PA`, no a un modelo dinamico. Esto sugiere que, en esa celda, suavizar/representar la superficie antes de persistirla ayuda marginalmente cuando se da mas peso al tramo corto. Aun asi, la conclusion econometrica se mantiene: los modelos dinamicos en puntajes no superan de forma sistematica a la persistencia.

## Archivos

Los resultados estan en:

```text
tesis_outputs/robustez_perdidas/losses_long.csv
tesis_outputs/robustez_perdidas/loss_summary_by_model.csv
tesis_outputs/robustez_perdidas/best_model_by_loss.csv
tesis_outputs/robustez_perdidas/pm_dominance_by_pair_loss.csv
tesis_outputs/robustez_perdidas/best_model_counts_by_loss.csv
tesis_outputs/robustez_perdidas/non_pm_winners.csv
```
