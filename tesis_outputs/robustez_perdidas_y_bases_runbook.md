# Robustez por funcion de perdida y especificacion de base

Este documento resume los cambios agregados al pipeline para las pruebas de robustez sugeridas.

## 1. Robustez por funcion de perdida

La robustez por funcion de perdida fue integrada en `tesis_volatilidad_analysis_final.R`.

Cuando se ejecuta el backtest final, el script ahora calcula, para cada par, horizonte, fecha objetivo y modelo:

- `RMSE`
- `MAE`
- `WRMSE_short`: RMSE ponderado hacia vencimientos cortos
- `WRMSE_long`: RMSE ponderado hacia vencimientos largos

La convencion de pesos respeta el orden corregido del pipeline:

```r
y = arrange(t_anos, delta)
X = kronecker(Phi_t, Phi_d)
```

Por eso la grilla de pesos se construye como:

```r
loss_grid <- expand.grid(
  tenor = TENOR_VALS,
  delta = DELTA_VALS
) %>%
  arrange(tenor, delta)
```

Los pesos son:

```r
w_short <- 1 / sqrt(loss_grid$tenor)
w_short <- w_short / mean(w_short)

w_long <- sqrt(loss_grid$tenor)
w_long <- w_long / mean(w_long)
```

Esto mantiene el promedio de los pesos en 1 y cambia solo la importancia relativa por tenor.

## 2. Archivos generados por robustez de perdida

En cada carpeta `tesis_outputs/<moneda>/`, el pipeline principal ahora guarda:

```text
tabla_losses_long.csv
tabla_robust_loss.csv
tabla_best_by_loss.csv
tabla_pm_dominance_loss.csv
```

Interpretacion:

- `tabla_losses_long.csv`: perdida por fecha, horizonte y modelo.
- `tabla_robust_loss.csv`: medianas por modelo y funcion de perdida.
- `tabla_best_by_loss.csv`: mejor modelo por par, horizonte y perdida.
- `tabla_pm_dominance_loss.csv`: proporcion de casos donde PM es el mejor modelo por funcion de perdida.

## 3. Robustez de base B-spline

La robustez de base se preparo como un script separado:

```text
tesis_basis_robustness.R
```

Se mantiene fuera del pipeline principal porque puede tardar mucho. El objetivo es evaluar si la conclusion principal depende de usar exactamente la base principal `4x8`.

Las bases configuradas son:

| basis_id | K_delta | K_tenor | Interpretacion |
|---|---:|---:|---|
| `base_4x8` | 4 | 8 | Especificacion principal |
| `coarse_4x6` | 4 | 6 | Base mas parsimoniosa |
| `rich_5x10` | 5 | 10 | Base mas flexible |

Para aislar el efecto de la base:

- Se reestiman los coeficientes B-spline bajo cada base.
- Se recalcula la FPCA rolling-local.
- Se mantiene fijo el `TRAIN_SIZE` seleccionado en la especificacion principal, leido desde `tesis_outputs/<moneda>/tesis_resultados.rds`.
- Se reoptimiza `K0` por horizonte y por base.
- Se vuelve a ejecutar el backtest final bajo esa base.

Si no existe el RDS principal, el script usa `BASIS_ROBUSTNESS_TRAIN_SIZE_FALLBACK`, por defecto 80.

## 4. Ejecucion overnight recomendada

Desde la raiz del repo:

```powershell
$env:BASIS_ROBUSTNESS_MONEDAS='usdpen,usdcop,usdclp,usdbrl,usdars,usdmxn,eurusd,usdzar'
$env:BASIS_ROBUSTNESS_BASIS_IDS='base_4x8,coarse_4x6,rich_5x10'
$env:BASIS_ROBUSTNESS_MAX_K0='15'
$env:BASIS_ROBUSTNESS_INCLUDE_KERNEL='TRUE'
Remove-Item Env:\BASIS_ROBUSTNESS_TRAIN_SIZE_OVERRIDE -ErrorAction SilentlyContinue
& 'C:\Program Files\R\R-4.5.0\bin\Rscript.exe' '.\tesis_basis_robustness.R'
```

Nota: `BASIS_ROBUSTNESS_TRAIN_SIZE_OVERRIDE` se uso solo para una prueba rapida de humo. Para la corrida real, debe estar vacio para que el script use el `TRAIN_SIZE` de la corrida principal.

## 5. Archivos generados por robustez de base

El script guarda resultados en:

```text
tesis_outputs/robustez_bases/
```

Archivos:

```text
basis_robustness_status.csv
tabla_basis_losses_long.csv
tabla_basis_robust_loss.csv
tabla_basis_best_by_loss.csv
tabla_basis_pm_dominance.csv
tabla_basis_tuning_k0.csv
```

Interpretacion:

- `basis_robustness_status.csv`: estado de cada par-base.
- `tabla_basis_losses_long.csv`: perdidas por fecha, horizonte, modelo y base.
- `tabla_basis_robust_loss.csv`: medianas por perdida/modelo/base.
- `tabla_basis_best_by_loss.csv`: mejor modelo por par, horizonte, base y perdida.
- `tabla_basis_pm_dominance.csv`: cuantos casos gana PM por base y funcion de perdida.
- `tabla_basis_tuning_k0.csv`: resultados del retuning de `K0` con `TRAIN_SIZE` fijo.

## 6. Frase metodologica sugerida

> Como prueba de robustez, se evaluo si la dominancia del benchmark de persistencia dependia de la funcion de perdida o de la especificacion de la base B-spline. Para ello, se repitio la comparacion usando MAE y RMSE ponderado hacia vencimientos cortos y largos. Adicionalmente, se preparo una corrida con bases alternativas mas parsimoniosas y mas flexibles, manteniendo fija la ventana temporal seleccionada en la especificacion principal y reoptimizando solo el numero de componentes `K0`.
