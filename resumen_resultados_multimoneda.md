# Resumen de resultados multimoneda

Fecha de corte del resumen: 2026-05-20.

Fuentes principales:

- `tesis_outputs/multi_moneda_status.csv`
- `tesis_outputs/resumen_disponibilidad_fpca.csv`
- `tesis_outputs/resumen_global_multimoneda.csv`
- `tesis_outputs/resumen_tuning_train_k0.csv`
- `tesis_outputs/resumen_rmse_wide.csv`
- `tesis_outputs/resumen_tasa_aciertos.csv`
- `tesis_outputs/resumen_dm.csv`
- `tesis_outputs/resumen_pair_narrative_metrics.csv`
- `tesis_outputs/resumen_estabilidad_modelos.csv`

## Lectura ejecutiva

La corrida final cubre 8 pares de divisas, 299 superficies completas por par y 3 horizontes de pronostico (`h=1,5,10`). La FPCA confirma una estructura funcional de baja dimension en todos los pares: una o dos componentes alcanzan 95% de varianza explicada, y dos o tres componentes alcanzan 99%.

El resultado predictivo es claro: bajo RMSE mediano sobre la malla observada, la persistencia cruda (`PM`) domina en los 24 casos par-horizonte. Los modelos `PA`, `VAR1`, `ARHinc` y `KernelARH` no superan a `PM` en mediana. Las pruebas Diebold-Mariano identifican inferioridad estadisticamente significativa de las alternativas frente a `PM` en 86 de 96 comparaciones; en las 10 restantes no hay evidencia de mejora, y `PM` sigue teniendo menor RMSE mediano.

## Estado de corrida

| Par | Estado |
|---|---:|
| USD/PEN | OK |
| USD/COP | OK |
| USD/CLP | OK |
| USD/BRL | OK |
| USD/ARS | OK |
| USD/MXN | OK |
| EUR/USD | OK |
| USD/ZAR | OK |

## Disponibilidad y FPCA global

| Par | Dias | Periodo | PC1 | PC1-PC2 | PC1-PC3 | K95 | K99 | RMSE base mediano |
|---|---:|---|---:|---:|---:|---:|---:|---:|
| USD/PEN | 299 | 2025-02-04 a 2026-03-27 | 0.7405 | 0.9805 | 0.9937 | 2 | 3 | 0.9164 |
| USD/COP | 299 | 2025-02-04 a 2026-03-27 | 0.9246 | 0.9809 | 0.9962 | 2 | 3 | 0.6023 |
| USD/CLP | 299 | 2025-02-04 a 2026-03-27 | 0.9892 | 0.9964 | 0.9996 | 1 | 2 | 0.5792 |
| USD/BRL | 299 | 2025-02-04 a 2026-03-27 | 0.9877 | 0.9962 | 0.9986 | 1 | 2 | 0.6297 |
| USD/ARS | 299 | 2025-02-04 a 2026-03-27 | 0.9834 | 0.9955 | 0.9983 | 1 | 2 | 1.2879 |
| USD/MXN | 299 | 2025-02-04 a 2026-03-27 | 0.9472 | 0.9845 | 0.9975 | 2 | 3 | 0.5956 |
| EUR/USD | 299 | 2025-02-04 a 2026-03-27 | 0.9566 | 0.9775 | 0.9907 | 1 | 3 | 0.3952 |
| USD/ZAR | 299 | 2025-02-04 a 2026-03-27 | 0.9550 | 0.9871 | 0.9978 | 1 | 3 | 0.5525 |

Interpretacion: H1 queda apoyada. Las superficies son altamente compresibles, con heterogeneidad entre pares. USD/PEN es el caso mas bifactorial; USD/CLP, USD/BRL y USD/ARS son casi unifactoriales bajo FPCA global.

## Dinamica de puntajes FPCA

| Par | PC1 ACF1 | PC1 cambio neto/sd | PC2 ACF1 | PC2 cambio neto/sd | PC3 ACF1 |
|---|---:|---:|---:|---:|---:|
| USD/PEN | 0.8337 | -3.7885 | 0.9147 | 2.3098 | 0.9091 |
| USD/COP | 0.8676 | -3.5147 | 0.9681 | 1.6021 | 0.8990 |
| USD/CLP | 0.9334 | 0.9096 | 0.9795 | -1.5514 | 0.9329 |
| USD/BRL | 0.9410 | 1.3743 | 0.7589 | 2.7183 | 0.9533 |
| USD/ARS | 0.9859 | 1.7586 | 0.8966 | 0.2878 | 0.9808 |
| USD/MXN | 0.8639 | -0.2061 | 0.9774 | -3.0282 | 0.8404 |
| EUR/USD | 0.8258 | 0.4666 | 0.8006 | -1.0801 | 0.9583 |
| USD/ZAR | 0.9031 | 2.7334 | 0.9625 | -0.8375 | 0.7961 |

Interpretacion: los puntajes son persistentes. La falta de ganancia predictiva no se explica por ausencia de memoria temporal, sino por el costo conjunto de suavizado, truncacion, reconstruccion y estimacion dinamica frente a `PM`.

## Tuning seleccionado

| Par | TRAIN_SIZE | N OOS | K0 h=1 | K0 h=5 | K0 h=10 |
|---|---:|---:|---:|---:|---:|
| USD/PEN | 44 | 245 | 4 | 4 | 4 |
| USD/COP | 154 | 135 | 7 | 8 | 8 |
| USD/CLP | 88 | 201 | 7 | 6 | 7 |
| USD/BRL | 132 | 157 | 7 | 6 | 5 |
| USD/ARS | 110 | 179 | 8 | 7 | 5 |
| USD/MXN | 88 | 201 | 7 | 6 | 6 |
| EUR/USD | 110 | 179 | 8 | 8 | 6 |
| USD/ZAR | 66 | 223 | 5 | 4 | 3 |

Interpretacion: no existe una ventana universal. USD/PEN selecciona una ventana corta de 44 dias; USD/COP selecciona 154 dias; USD/BRL 132 dias. Esto sugiere heterogeneidad y no estacionariedad local por par.

## RMSE mediano OOS

| Par | h | PM | PA | VAR1 | ARHinc | KernelARH | Mejor no-PM | Brecha vs PM | PM domina |
|---|---:|---:|---:|---:|---:|---:|---|---:|---|
| USD/PEN | 1 | 0.1200 | 0.9670 | 7.5540 | 0.9679 | 0.9727 | PA | 0.8470 | TRUE |
| USD/PEN | 5 | 0.3227 | 1.0014 | 10.8560 | 0.9998 | 1.0076 | ARHinc | 0.6771 | TRUE |
| USD/PEN | 10 | 0.4223 | 1.0394 | 8.9306 | 1.0430 | 1.0566 | PA | 0.6171 | TRUE |
| USD/COP | 1 | 0.1504 | 0.5356 | 39.3748 | 0.5389 | 0.5494 | PA | 0.3852 | TRUE |
| USD/COP | 5 | 0.4321 | 0.6613 | 96.8628 | 0.6703 | 0.6994 | PA | 0.2292 | TRUE |
| USD/COP | 10 | 0.6441 | 0.8163 | 63.3414 | 0.8070 | 0.8680 | ARHinc | 0.1629 | TRUE |
| USD/CLP | 1 | 0.1614 | 0.6272 | 122.8315 | 0.6313 | 0.6438 | PA | 0.4658 | TRUE |
| USD/CLP | 5 | 0.4087 | 0.7015 | 153.1490 | 0.7245 | 0.7339 | PA | 0.2928 | TRUE |
| USD/CLP | 10 | 0.6239 | 0.8420 | 198.9688 | 0.8362 | 0.8122 | KernelARH | 0.1883 | TRUE |
| USD/BRL | 1 | 0.1972 | 0.6654 | 46.3052 | 0.6817 | 0.6807 | PA | 0.4682 | TRUE |
| USD/BRL | 5 | 0.5848 | 0.8451 | 99.5407 | 0.8287 | 0.8995 | ARHinc | 0.2439 | TRUE |
| USD/BRL | 10 | 0.7676 | 0.9835 | 113.7875 | 1.0143 | 0.9991 | PA | 0.2159 | TRUE |
| USD/ARS | 1 | 0.1729 | 1.2766 | 172.6874 | 1.2837 | 1.2875 | PA | 1.1037 | TRUE |
| USD/ARS | 5 | 0.4415 | 1.3542 | 255.3009 | 1.3660 | 1.3722 | PA | 0.9127 | TRUE |
| USD/ARS | 10 | 0.6258 | 1.4207 | 25.4308 | 1.4341 | 1.4554 | PA | 0.7949 | TRUE |
| USD/MXN | 1 | 0.1470 | 0.6072 | 21.8129 | 0.6084 | 0.6138 | PA | 0.4602 | TRUE |
| USD/MXN | 5 | 0.3419 | 0.6646 | 27.2850 | 0.6709 | 0.6842 | PA | 0.3227 | TRUE |
| USD/MXN | 10 | 0.4251 | 0.6899 | 23.8348 | 0.7002 | 0.7676 | PA | 0.2648 | TRUE |
| EUR/USD | 1 | 0.1588 | 0.4205 | 64.9212 | 0.4304 | 0.4426 | PA | 0.2617 | TRUE |
| EUR/USD | 5 | 0.3741 | 0.5367 | 68.9032 | 0.5470 | 0.5960 | PA | 0.1626 | TRUE |
| EUR/USD | 10 | 0.4908 | 0.5982 | 32.3921 | 0.6033 | 0.7082 | PA | 0.1074 | TRUE |
| USD/ZAR | 1 | 0.1750 | 0.6052 | 14.2564 | 0.6088 | 0.6193 | PA | 0.4302 | TRUE |
| USD/ZAR | 5 | 0.4172 | 0.7153 | 20.6145 | 0.7071 | 0.7253 | ARHinc | 0.2899 | TRUE |
| USD/ZAR | 10 | 0.5551 | 0.7836 | 9.2332 | 0.7759 | 0.8464 | ARHinc | 0.2208 | TRUE |

Interpretacion: H2 queda rechazada. La mejor alternativa no-PM siempre tiene mayor RMSE mediano que `PM`.

## Maxima tasa de acierto frente a PM por par

| Par | Max TA | Modelo | h |
|---|---:|---|---:|
| USD/PEN | 0.008 | KernelARH | 5 |
| USD/COP | 0.119 | KernelARH | 10 |
| USD/CLP | 0.174 | KernelARH | 10 |
| USD/BRL | 0.274 | KernelARH | 10 |
| USD/ARS | 0.006 | KernelARH | 10 |
| USD/MXN | 0.065 | KernelARH | 10 |
| EUR/USD | 0.173 | KernelARH | 10 |
| USD/ZAR | 0.067 | KernelARH | 10 |

Interpretacion: las alternativas pueden ganar en fechas puntuales, sobre todo KernelARH a h=10, pero no ganan en mediana. El caso mas alto es USD/BRL h=10 con TA=0.274, pero su RMSE mediano sigue siendo 0.9991 frente a 0.7676 de PM.

## Diebold-Mariano

| Par | Comparaciones inferiores a PM al 5% | Total | No inferiores al 5% |
|---|---:|---:|---:|
| USD/PEN | 12 | 12 | 0 |
| USD/COP | 12 | 12 | 0 |
| USD/CLP | 11 | 12 | 1 |
| USD/BRL | 11 | 12 | 1 |
| USD/ARS | 12 | 12 | 0 |
| USD/MXN | 11 | 12 | 1 |
| EUR/USD | 10 | 12 | 2 |
| USD/ZAR | 7 | 12 | 5 |
| **Total** | **86** | **96** | **10** |

Interpretacion: donde DM no declara inferioridad al 5%, tampoco hay evidencia de mejora. En todos esos casos, `PM` mantiene menor RMSE mediano.

## Estabilidad y diagnosticos

| Par | VAR1 rmax | VAR1 ratio p95 max | Kernel rmax | Kernel prop r>=1 max | Subespacio p95 | Subespacio max |
|---|---:|---:|---:|---:|---:|---:|
| USD/PEN | 1.3019 | 25.0610 | 1.0053 | 0.004 | 0.4516 | 1.4016 |
| USD/COP | 1.0312 | 23.7023 | 0.9888 | 0.000 | 0.1883 | 0.7949 |
| USD/CLP | 1.1202 | 106.6882 | 1.0427 | 0.015 | 0.2720 | 1.0606 |
| USD/BRL | 1.0175 | 20.8604 | 0.9857 | 0.000 | 0.3428 | 1.3467 |
| USD/ARS | 1.0820 | 33.9676 | 1.0794 | 0.011 | 0.2996 | 1.3714 |
| USD/MXN | 1.1199 | 35.8422 | 0.9838 | 0.000 | 0.3662 | 1.4139 |
| EUR/USD | 1.1214 | 37.4200 | 1.1355 | 0.006 | 0.2177 | 0.7186 |
| USD/ZAR | 1.1921 | 13.6076 | 1.3633 | 0.009 | 0.4110 | 1.4120 |

Interpretacion:

- `VAR1` es el modelo dinamicamente mas fragil: su radio espectral maximo supera 1 en todos los pares y los ratios de norma pueden ser muy grandes.
- `ARHinc` es mas estable que `VAR1`; casi no presenta radios espectrales mayores o iguales a 1.
- `KernelARH` tambien es relativamente estable en varios pares, pero no transforma esa estabilidad en superioridad predictiva.
- Los subespacios FPCA rolling son suficientemente estables para sostener la interpretacion descriptiva, aunque existen episodios de deriva subespacial.

## Conclusiones para la tesis

- H1 queda apoyada: la representacion funcional FPCA es parsimoniosa e interpretable.
- H2 queda rechazada: los modelos dinamicos sobre puntajes FPCA no superan a la persistencia cruda bajo RMSE mediano.
- H3 queda apoyada: `PM` es un benchmark fuerte para horizontes cortos y medianos en superficies de volatilidad altamente persistentes.
- La tesis debe formularse como un resultado descriptivo fuerte y un resultado predictivo negativo informativo, no como una tesis de mejora predictiva.

