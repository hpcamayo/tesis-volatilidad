# Rolling FPCA como diagnostico de cambios de regimen

Este documento explica la seccion nueva agregada al pipeline principal para estudiar si la estructura de componentes principales funcionales cambia en el tiempo. El objetivo de esta seccion es descriptivo: no reemplaza los modelos dinamicos, no reentrena los backtests y no cambia la forma en que se evalua el pronostico. Su funcion es responder una pregunta previa:

> La FPCA global de 299 dias, realmente representa una estructura estable de la superficie, o esta mezclando varios regimenes locales?

## 1. Motivacion

En la FPCA global se calcula una unica base de componentes principales usando toda la muestra disponible. Eso es util para resumir la variacion total, pero puede esconder cambios estructurales. Por ejemplo, si durante tres meses la superficie se mueve casi como un factor de nivel, y luego durante otros tres meses el factor dominante cambia hacia un movimiento de skew o de estructura temporal, la FPCA global puede repartir la varianza entre PC1 y PC2 aunque cada subperiodo sea localmente simple.

Por eso se agrego una FPCA rolling: se recalcula la FPCA en ventanas moviles cortas y medianas, y se compara la estructura local con la FPCA global.

## 2. Ventanas usadas

Se usaron ventanas de dias habiles:

| Ventana | Interpretacion aproximada |
|---:|---|
| 22 dias | 1 mes |
| 44 dias | 2 meses |
| 66 dias | 3 meses |
| 88 dias | 4 meses |
| 110 dias | 5 meses |
| 132 dias | 6 meses |

La ventana de 22 dias es mas ruidosa, pero permite detectar cambios rapidos. Las ventanas de 66 a 132 dias son mas estables y sirven mejor para hablar de regimenes persistentes.

## 3. Donde entra en el pipeline

La seccion se agrego despues de la FPCA global con correccion Gram-Cholesky y antes de los bloques dinamicos.

El flujo es:

1. Cargar las superficies observadas.
2. Estimar coeficientes diarios en la base B-spline tensorial.
3. Construir la metrica funcional mediante la matriz de Gram.
4. Calcular la FPCA global sobre toda la muestra.
5. Calcular la FPCA rolling en ventanas moviles de 1 a 6 meses.
6. Guardar tablas y figuras descriptivas.
7. Solo si no se activa el modo parcial, continuar con los modelos dinamicos.

Para evitar ejecutar los modelos dinamicos cuando solo se quiere esta seccion, se agrego la bandera:

```powershell
$env:STOP_AFTER_ROLLING_FPCA='TRUE'
```

Con esa bandera, el script termina inmediatamente despues de guardar los resultados rolling FPCA.

## 4. Calculo de la FPCA rolling

Para cada par de divisas y para cada ventana `W`, se toman todas las submuestras consecutivas de longitud `W`. Si la muestra tiene 299 dias, una ventana de 66 dias produce `299 - 66 + 1 = 234` FPCAs locales.

En cada ventana:

1. Se toman los coeficientes B-spline diarios de esa ventana.
2. Se centran respecto a la media local de la ventana.
3. Se aplica la transformacion metrica:

```r
U_w <- cc_w %*% t(S)
```

donde `S` es el factor de Cholesky de la matriz de Gram global. Esto mantiene la FPCA en la geometria funcional correcta, no en una geometria euclidiana arbitraria de coeficientes.

4. Se ejecuta PCA ordinaria sobre `U_w`:

```r
fp_w <- prcomp(U_w, center = FALSE, scale. = FALSE)
```

5. Se calculan las proporciones de varianza explicada:

```r
ve <- fp_w$sdev^2 / sum(fp_w$sdev^2)
cv <- cumsum(ve)
```

## 5. Metricas registradas

Para cada ventana movil se guardan:

| Metrica | Significado |
|---|---|
| `PC1` | Proporcion de varianza explicada por la primera componente local |
| `PC2` | Proporcion de varianza explicada por la segunda componente local |
| `PC3` | Proporcion de varianza explicada por la tercera componente local |
| `PC1_PC2` | Varianza acumulada explicada por las dos primeras componentes |
| `PC1_PC3` | Varianza acumulada explicada por las tres primeras componentes |
| `K95` | Numero minimo de componentes para explicar 95% de la varianza local |
| `K99` | Numero minimo de componentes para explicar 99% de la varianza local |
| `dist_global3` | Distancia entre el subespacio local PC1-PC3 y el subespacio global PC1-PC3 |
| `dist_prev3` | Distancia entre el subespacio local PC1-PC3 y el de la ventana anterior |

## 6. Distancia subespacial

La distancia subespacial se calcula comparando proyectores. Si `A` contiene las primeras tres componentes locales y `B` contiene las primeras tres componentes globales:

```r
P_A <- A %*% t(A)
P_B <- B %*% t(B)
dist <- sqrt(sum((P_A - P_B)^2))
```

Esta distancia es cero si los subespacios son identicos. Valores mayores indican que las direcciones principales locales se alejan de las direcciones globales.

La ventaja de usar proyectores es que la comparacion no depende del signo arbitrario de las componentes. En PCA, una componente puede aparecer multiplicada por `-1` sin cambiar su significado; la distancia entre proyectores evita que ese cambio de signo se lea falsamente como inestabilidad.

## 7. Archivos generados

Por cada moneda se generan:

```text
tesis_outputs/<moneda>/tabla_fpca_rolling.csv
tesis_outputs/<moneda>/tabla_fpca_rolling_resumen.csv
tesis_outputs/<moneda>/fig_rolling_fpca_varianza.pdf
tesis_outputs/<moneda>/fig_rolling_fpca_k95_k99.pdf
tesis_outputs/<moneda>/fig_rolling_fpca_distancias.pdf
tesis_outputs/<moneda>/tesis_resultados_rolling_fpca.rds
```

Tambien se agregaron archivos agregados multimoneda:

```text
tesis_outputs/rolling_fpca_resumen_multimoneda.csv
tesis_outputs/rolling_fpca_resumen_multimoneda_compacto.csv
tesis_outputs/rolling_fpca_analisis_multimoneda.md
```

## 8. Interpretacion de los resultados

La lectura principal es comparar la FPCA global con la FPCA local.

Si `PC1 global` y `PC1 rolling` son ambos altos, la superficie tiene una estructura estable y dominada por nivel. Esto ocurre claramente en USD/CLP, y en menor medida en USD/MXN, EUR/USD y USD/ZAR.

Si `PC1 rolling` es alto pero `PC1 global` es mucho menor, la muestra completa probablemente mezcla varios regimenes. Cada ventana local puede ser simple, pero el eje dominante cambia a lo largo del tiempo. Este es el caso mas claro de USD/PEN: globalmente PC1 explica 0.7405, pero localmente la mediana de PC1 esta cerca de 0.90.

Si el percentil bajo de `PC1 rolling` cae mucho, hay episodios donde la superficie deja de ser unifactorial. Esto aparece de forma importante en USD/ARS, donde algunas ventanas muestran PC1 local muy bajo, consistente con episodios de cambio de regimen.

Si `PC1` sigue alto pero `dist_global3` tambien es alto, el numero de factores no aumenta mucho, pero las formas de las componentes rotan. Esto se observa en USD/BRL: sigue siendo una superficie dominada por un factor, pero el factor local no siempre coincide con el factor global.

## 9. Implicacion para la tesis

Esta seccion permite matizar la interpretacion de la FPCA global:

- En pares estables, la FPCA global puede leerse como una representacion estructural de la superficie.
- En pares con cambios de regimen, la FPCA global debe leerse como un promedio de estados locales.
- Para USD/PEN y USD/ARS, la evidencia rolling justifica discutir extensiones futuras como FPCA por regimen, ventanas adaptativas o modelos con cambio de regimen.

Esto no invalida la FPCA global. La vuelve mas informativa: muestra que la baja dimension existe, pero que la geometria de esa baja dimension puede cambiar con el tiempo.

## 10. Como ejecutar solo esta seccion

Para una moneda:

```powershell
$env:MONEDA_WORK_OVERRIDE='usdpen'
$env:RUN_ALL_MONEDAS_OVERRIDE='FALSE'
$env:STOP_AFTER_ROLLING_FPCA='TRUE'
& 'C:\Program Files\R\R-4.5.0\bin\Rscript.exe' '.\tesis_volatilidad_analysis_final.R'
```

Para todas las monedas, se puede ejecutar el mismo esquema en un loop, manteniendo `STOP_AFTER_ROLLING_FPCA='TRUE'`.

## 11. Frase sugerida para la tesis

> Para evaluar si la estructura factorial obtenida con la FPCA global es estable en el tiempo, se recalculo la FPCA en ventanas moviles de 22 a 132 dias habiles. Este diagnostico permite distinguir entre superficies genuinamente unifactoriales y superficies que parecen multifactoriales en la muestra completa porque combinan distintos regimenes locales. La comparacion se realizo mediante la proporcion de varianza explicada por PC1 y PC2, los umbrales K95/K99 y la distancia entre los subespacios generados por las tres primeras componentes locales y globales.
