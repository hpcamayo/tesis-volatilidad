# Analisis rolling FPCA multimoneda

Este diagnostico usa la muestra completa de 299 dias por par, pero recalcula la FPCA en ventanas moviles de 22, 44, 66, 88, 110 y 132 dias habiles, aproximadamente 1 a 6 meses. No se ejecutaron modelos dinamicos ni backtests.

## Resumen compacto

| Par | PC1 global | PC2 global | PC1 med. 1m | PC1 med. 3m | PC1 med. 6m | PC2 med. 6m | K95 6m | K99 6m | Dist. global 6m |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| USD/PEN | 0.7405 | 0.2400 | 0.9288 | 0.8948 | 0.8966 | 0.0846 | 2 | 3 | 0.8069 |
| USD/COP | 0.9246 | 0.0563 | 0.9758 | 0.9473 | 0.9151 | 0.0711 | 2 | 3 | 0.3500 |
| USD/CLP | 0.9892 | 0.0072 | 0.9958 | 0.9955 | 0.9937 | 0.0041 | 1 | 1 | 0.3014 |
| USD/BRL | 0.9877 | 0.0085 | 0.9832 | 0.9777 | 0.9751 | 0.0177 | 1 | 2 | 0.7153 |
| USD/ARS | 0.9834 | 0.0121 | 0.9600 | 0.9304 | 0.9592 | 0.0316 | 1 | 2 | 0.8169 |
| USD/MXN | 0.9472 | 0.0373 | 0.9754 | 0.9620 | 0.9598 | 0.0319 | 1 | 2 | 0.4575 |
| EUR/USD | 0.9566 | 0.0209 | 0.9755 | 0.9695 | 0.9633 | 0.0210 | 1 | 3 | 0.4522 |
| USD/ZAR | 0.9550 | 0.0321 | 0.9808 | 0.9816 | 0.9550 | 0.0306 | 1 | 3 | 0.3012 |

## Lectura general

El PC1 global mide cuanto de toda la muestra completa se explica por un factor comun de nivel. El PC1 rolling mide si, dentro de ventanas locales, la superficie se comporta como un sistema mas simple. Cuando el PC1 rolling es mucho mayor que el PC1 global, la interpretacion natural es que cada subperiodo es relativamente simple, pero la combinacion de varios subperiodos cambia la geometria y reparte varianza hacia PC2 o PC3.

## Interpretacion por par

- USD/PEN: Es el caso mas claro de mezcla de regimenes. En la muestra global, PC1 cae a 0.7405 y PC2 sube a 0.2400; pero en ventanas rolling PC1 vuelve a estar cerca de 0.90. Esto sugiere que localmente la SVI es casi de baja dimension, pero el eje dominante cambia a traves del tiempo. Para la tesis, USD/PEN debe presentarse como el principal ejemplo donde la FPCA global resume el promedio de varios estados de mercado, no una estructura unica estable.
- USD/COP: El corto plazo es muy de nivel, con PC1 1m de 0.9758, pero al ir a 6m baja a 0.9151 y PC2 sube a 0.0711. Esto parece una segunda dimension lenta, no necesariamente un quiebre fuerte. La superficie mantiene estabilidad subespacial razonable, por lo que la lectura es de transicion gradual en skew/term structure.
- USD/CLP: Es el par mas estable y mas unifactorial. PC1 rolling queda arriba de 0.99 incluso a 6m, y K99 6m es 1. La volatilidad de CLP en esta muestra se mueve casi como desplazamiento paralelo de nivel. En esta malla, hay poca evidencia de cambios persistentes de forma.
- USD/BRL: Aunque globalmente parece casi unifactorial, la distancia subespacial es relativamente alta. Eso indica que el porcentaje de varianza sigue dominado por PC1, pero la forma del PC1 local puede rotar. Es decir, no aparece mucha PC2, pero el "nivel" no siempre significa exactamente la misma deformacion de superficie.
- USD/ARS: Es el caso mas inestable junto con USD/PEN. El PC1 mediano local cae hacia 0.92-0.93 en ventanas de 3 a 5 meses y el percentil 5 de PC1 es muy bajo, cercano a 0.53-0.58 en ventanas largas. Esto apunta a episodios concretos donde la superficie deja de ser unifactorial. Economicamente es consistente con cambios de regimen, controles, saltos de devaluacion esperada o repricing fuerte por vencimiento.
- USD/MXN: Es estable y relativamente liquido. PC1 rolling se mantiene alrededor de 0.96 y K95 6m es 1, aunque K99 necesita 2. La segunda componente existe, pero parece residual y ordenada. Interpretacion: dinamica dominada por nivel con ajustes moderados de skew/term tilt.
- EUR/USD: Mercado desarrollado de referencia. PC1 rolling esta cerca de 0.96-0.98, con PC2 alrededor de 0.02. K99 requiere 3 en 3m-6m, lo que sugiere pequenas variaciones de forma detectables, pero no un cambio estructural dominante. Sirve como benchmark de estabilidad alta con microestructura mas regular.
- USD/ZAR: Muy estable en distancia subespacial a 6m y PC1 rolling alto. A medida que crece la ventana, PC1 baja de 0.98 a 0.955 y K99 sube a 3, señal de factores secundarios pequenos pero persistentes. Parece mas estable que PEN/ARS y mas parecido a MXN/EUR en estructura.

## Implicacion metodologica

La FPCA global sigue siendo util como resumen descriptivo de toda la muestra, pero no debe interpretarse igual para todos los pares. En USD/CLP, USD/MXN, EUR/USD y USD/ZAR, la FPCA global es bastante representativa. En USD/PEN y USD/ARS, la FPCA global mezcla estados locales distintos, por lo que conviene reportar la rolling FPCA como evidencia de cambios de regimen. Para pronostico, esto respalda el uso de ventanas rolling/locales y, como extension futura, FPCA por regimen o modelos con cambio de regimen.
