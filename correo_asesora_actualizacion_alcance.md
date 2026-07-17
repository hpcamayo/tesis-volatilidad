# Correo a la asesora: actualización de alcance y nuevo borrador

**Asunto:** Actualización sustantiva del alcance y envío del nuevo borrador completo de tesis

Estimada profesora Felícita:

Espero que se encuentre muy bien. Le envío una versión profundamente revisada de la tesis y quisiera explicarle con cierto detalle por qué el alcance cambió respecto de la última versión oficial que presentamos en Seminario 2. No se trata solamente de una ampliación de muestra o de una corrección editorial. Al completar y auditar el ejercicio empírico, los resultados obligaron a reformular la pregunta predictiva y, con ello, la forma de presentar la contribución de la tesis.

La versión oficial de diciembre de 2025 trabajaba con 128 jornadas, hasta el 31 de julio de 2025, y concentraba el backtest principalmente en USD/PEN. En esa versión, los resultados sugerían que ARHinc mejoraba a la persistencia en los horizontes de cinco y diez días, por lo que la conclusión daba un lugar central a la posible superioridad de los modelos dinámicos construidos sobre puntajes FPCA. Al extender la muestra, reconstruir el pipeline final, verificar la convención de vectorización, reestimar cada ventana sin usar información futura y ejecutar el ejercicio completo para ocho pares, ese resultado no se sostuvo. En la especificación principal, la persistencia cruda sobre la malla observada obtiene el menor RMSE mediano en los ocho pares y los tres horizontes.

Por esa razón, el nuevo borrador separa dos preguntas que antes aparecían demasiado unidas:

1. **Pregunta descriptiva:** si las superficies de volatilidad implícita pueden representarse, comprimirse e interpretarse adecuadamente mediante B-splines tensoriales y FPCA con la métrica funcional correcta.
2. **Pregunta predictiva:** si los modelos dinámicos estimados sobre los puntajes FPCA mejoran el pronóstico fuera de muestra frente a la persistencia cruda.

La primera pregunta recibe una respuesta claramente favorable. La segunda recibe una respuesta negativa bajo el diseño empírico evaluado. El argumento central de la tesis pasa a ser, por tanto, que una representación funcional puede ser muy exitosa desde el punto de vista descriptivo sin garantizar superioridad predictiva frente a un benchmark especialmente fuerte. Considero que esta reformulación vuelve la contribución más precisa y defendible: la hipótesis predictiva se somete a una prueba exigente y se rechaza cuando la evidencia no la respalda, en lugar de preservar una conclusión favorable que desaparece con una muestra y una validación más completas.

## Cambio de alcance empírico

La base final contiene 299 superficies diarias completas para cada uno de los ocho pares, entre el 4 de febrero de 2025 y el 27 de marzo de 2026. Los pares son USD/PEN, USD/COP, USD/CLP, USD/BRL, USD/ARS, USD/MXN, EUR/USD y USD/ZAR. Cada superficie conserva la misma malla de cinco deltas por trece tenores, es decir, 65 nodos.

El análisis ya no utiliza los otros pares solo como contexto descriptivo. Cada moneda se procesa de manera independiente y recibe su propio ajuste funcional, FPCA, selección de ventana, selección de componentes, backtest y diagnósticos. Esto permite distinguir patrones comunes de diferencias importantes entre mercados, sin convertir el ejercicio en un modelo panel ni atribuir causalidad macroeconómica a diferencias que la tesis no identifica.

Los resultados descriptivos son fuertes. En todos los pares, una o dos componentes explican al menos 95% de la variación funcional, y dos o tres componentes explican al menos 99%. USD/PEN es el caso más bifactorial: PC1 explica 74.05% y PC2 24.00%, por lo que ambas acumulan 98.05%. USD/CLP, USD/BRL y USD/ARS son mucho más unifactoriales. Esta heterogeneidad ahora se analiza tanto globalmente como mediante FPCA rolling.

En cambio, bajo RMSE sobre la malla observada, PM obtiene la menor mediana en las 24 combinaciones principales de par y horizonte. Para USD/PEN, por ejemplo, PM registra RMSE medianos de 0.1200, 0.3227 y 0.4223 en los horizontes de uno, cinco y diez días. Las mejores alternativas no PM registran 0.9670, 0.9998 y 1.0394, respectivamente. Las tasas de acierto y las pruebas de Diebold-Mariano apuntan en la misma dirección. La robustez por función de pérdida conserva el patrón: PM gana las 24 celdas bajo RMSE, MAE y RMSE ponderado hacia vencimientos largos, y 23 de 24 bajo ponderación hacia vencimientos cortos. La única excepción de esa última pérdida corresponde a PA en USD/COP a diez días, no a un modelo dinámico.

## Flujo de trabajo final

El nuevo borrador describe el procedimiento completo de manera secuencial y reproducible:

1. Se leen las ocho hojas del archivo Bloomberg, se convierten los tenores a años y se retienen solo fechas con los 65 nodos completos.
2. Cada superficie diaria se aproxima mediante una base B-spline tensorial. Se documentan el diseño, la convención de vectorización, el ajuste ridge, los residuos, el leverage y el error de reconstrucción.
3. Se construye la matriz de Gram tensorial y se aplica la corrección Gram--Cholesky para que la FPCA se estime en la geometría de L2(delta por tenor), no en la geometría euclidiana arbitraria de los coeficientes.
4. Se calculan eigensuperficies, puntajes, fracciones de varianza explicada, dimensiones K95/K99 y trayectorias temporales de los puntajes.
5. Se ejecuta FPCA rolling con ventanas de 22, 44, 66, 88, 110 y 132 días para estudiar dimensión local y rotación del subespacio respecto de la FPCA global.
6. Para el backtest se seleccionan ventana de entrenamiento y K0, y se reestima la FPCA local en cada origen usando solamente observaciones disponibles hasta esa fecha.
7. Se comparan cinco modelos: persistencia cruda (PM), persistencia de la superficie ajustada (PA), VAR(1) en puntajes, ARH en incrementos y KernelARH.
8. Los pronósticos se evalúan en horizontes de uno, cinco y diez días mediante RMSE, MAE, RMSE ponderado hacia vencimientos cortos y RMSE ponderado hacia vencimientos largos.
9. Se complementan las medianas con tasas de acierto frente a PM, intervalos, pruebas de Diebold-Mariano y diagnósticos de estabilidad numérica.
10. Se realizan pruebas de robustez con tres resoluciones de base: 4x6, 4x8 y 5x10, reoptimizando K0 dentro de cada especificación.

Esta secuencia se incorporó a la metodología mediante ocho algoritmos explicados paso a paso. También se agregó un apéndice que relaciona cada algoritmo con las funciones del código y sus archivos de salida. Esto responde directamente a la recomendación del jurado de no limitarse a mencionar un algoritmo, sino explicar con claridad sus entradas, transformaciones, decisiones y salidas.

## Nuevas secciones y ampliaciones

Respecto de la versión oficial, el nuevo borrador incorpora o amplia los siguientes bloques:

- Una formulación explícita de tres hipótesis. H1, sobre baja dimensión funcional, queda respaldada; H2, sobre superioridad predictiva de los modelos dinámicos, se rechaza; H3, sobre la dificultad de superar la persistencia, queda fuertemente respaldada en la muestra.
- Una revisión de literatura reorganizada alrededor de superficies de volatilidad, FDA/FPCA, B-splines, series funcionales, regresión kernel y benchmarks de persistencia.
- Una explicación más extensa de opciones, delta, moneyness, ATM, risk reversal, butterfly, smile, skew y estructura temporal.
- Un desarrollo matemático ampliado de espacios de Hilbert, producto interno, norma, proyección, bases B-spline, producto tensorial, matriz de Gram, FPCA y reconstrucción.
- Un análisis completo de los puntajes FPCA, incluyendo orientación de signo, autocorrelaciones, cambios netos y diferencias entre componentes de nivel y forma.
- FPCA rolling como diagnóstico de cambios en la dimensión local y en la geometría de los factores.
- Una lectura descriptiva y predictiva individual de cada uno de los ocho pares, seguida de una comparación transversal.
- Una sección de estabilidad que documenta la fragilidad de VAR1 y la mayor estabilidad relativa de ARHinc y KernelARH, sin confundir estabilidad numérica con mejor capacidad predictiva.
- Robustez frente a funciones de pérdida y resolución de la base B-spline.
- Un estudio Monte Carlo completo con 1,000 replicaciones, T=220, ventana de 80 observaciones, K0=3 y tres procesos generadores: alta persistencia, baja persistencia y cambio de régimen.
- Nuevas figuras de simulación que muestran que el mismo pipeline favorece PM cuando la persistencia verdadera es extrema, pero favorece VAR1 o KernelARH cuando la persistencia es baja. Esto es importante porque demuestra que la dominancia empírica de PM no está impuesta mecánicamente por el procedimiento.
- Una visualización tridimensional del ajuste USD/PEN en el dominio completo y en vencimientos cortos, con los nodos observados y residuos superpuestos.
- Una discusión, limitaciones y agenda futura considerablemente ampliadas.
- Un apéndice de reproducibilidad y correspondencia entre algoritmos, código y salidas.

El borrador también restaura y expande el nivel de detalle explicativo de la versión oficial. La versión actual tiene 73 páginas, frente a 45 páginas de la última versión oficial. El aumento no proviene de repetir resultados, sino de hacer explícitas las etapas metodológicas, analizar todos los pares, documentar robustez, validar el pipeline mediante simulación y discutir con mayor cuidado el alcance de cada conclusión.

## Interpretación del resultado negativo

La tesis no afirma que FPCA o los modelos funcionales sean inútiles. La evidencia muestra que la FPCA representa muy bien la variación conjunta y permite comprimir las superficies en pocos factores interpretables. Lo que no aparece es valor predictivo incremental suficiente para compensar tres costos: suavizado y reconstrucción, truncamiento y estimación dinámica.

PM tiene una ventaja estructural bajo la pérdida principal: copia directamente la última malla y no incurre en error de reconstrucción. PA y todos los modelos dinámicos pasan por la base B-spline. En USD/PEN, la mediana del RMSE de ajuste de base es 0.9164 puntos porcentuales, superior al error mediano de PM en los tres horizontes. La alta varianza explicada por FPCA no elimina este costo, porque explicar varianza histórica y minimizar error de pronóstico nodo por nodo son objetivos diferentes.

Los diagnósticos también ayudan a interpretar el resultado. VAR1 presenta ventanas cercanas a la raíz unitaria o inestables y puede amplificar pronósticos. ARHinc y KernelARH son más estables, pero aun así no vencen sistemáticamente a PM. Las ventanas cortas y la FPCA rolling sugieren heterogeneidad local, aunque esta tampoco rescata de forma general a los modelos dinámicos.

## Limitaciones declaradas con mayor precisión

La nueva versión hace explícitas varias limitaciones que antes no estaban suficientemente desarrolladas:

- Cada pronóstico se estima sin usar observaciones posteriores al origen, pero la selección global de ventana y K0 resume resultados sobre la misma secuencia histórica. Por ello, el diseño no se presenta como una validación temporal anidada con un bloque final completamente reservado.
- La pérdida principal se calcula sobre la malla observada y favorece métodos que no reconstruyen. Se incorporan otras pérdidas, pero no se afirma que estas agoten criterios económicamente relevantes.
- La representación no impone no arbitraje, positividad ni restricciones de forma en todo el dominio continuo.
- El diagnóstico tridimensional detectó que una evaluación cúbica densa puede oscilar entre nodos. Por transparencia, la figura principal interpola bilinealmente los valores B-spline ajustados en la malla y ninguna conclusión numérica depende de puntos intermedios no observados.
- La muestra sigue siendo relativamente corta para modelos dinámicos flexibles y cubre un único período común.
- No se incorporan variables exógenas ni se formulan explicaciones causales por moneda.
- El rechazo de H2 se limita a los modelos, datos, horizontes y pérdidas evaluados; no se generaliza a toda posible metodología funcional.

## Revisión bibliográfica

Se realizó también una auditoría completa de la bibliografía. El borrador contiene 44 referencias citadas, sin claves indefinidas, duplicadas ni entradas sin uso. Se verificaron DOI y metadatos editoriales cuando estaban disponibles, se corrigieron referencias antiguas con datos incompletos y se agregaron fuentes para convenciones de opciones FX, persistencia como benchmark, backtesting rolling, corrección de Diebold--Mariano, estabilidad de subespacios y simulación con dependencia funcional. Cuando una afirmación correspondía a una decisión propia de diseño, se la identificó como tal en lugar de buscar una cita decorativa.

## Decisiones sobre las que agradecería su orientación

Me gustaría especialmente conocer su opinión sobre los siguientes puntos:

1. Si considera adecuada la reformulación central entre éxito descriptivo y éxito predictivo.
2. Si el título actual refleja bien el nuevo alcance o conviene enfatizar aún más la evaluación contra persistencia.
3. Si el capítulo de simulación debe permanecer en el cuerpo principal o trasladarse parcialmente a un anexo.
4. Si el análisis individual de los ocho pares debe mantenerse completo en resultados o resumirse, dejando parte del detalle en apéndices.
5. Si la robustez por base y función de pérdida debe permanecer en el cuerpo principal.
6. Si la explicación de la selección no anidada y de la visualización entre nodos le parece suficientemente clara.
7. Si el formato final requiere ajustes institucionales adicionales de portada, resumen, anexos o bibliografía.

Adjunto únicamente el nuevo PDF completo para que la revisión no dependa de navegar scripts, CSV o carpetas de figuras. El código, las salidas resumidas y la bitácora de cambios están versionados en el repositorio y puedo compartir cualquier elemento específico que considere necesario. La versión oficial anterior se preservó sin modificaciones, de modo que ambas versiones pueden compararse directamente.

Muchas gracias por su tiempo y por las observaciones de la asesoría y del jurado. En particular, procuré que cada algoritmo utilizado quedara explicado paso a paso en la metodología y que el resultado empírico final se presentara con transparencia, aun cuando modificara la expectativa predictiva inicial. Quedo atento a sus comentarios para realizar la revisión editorial final y definir la estructura definitiva.

Saludos cordiales,

Henri Camayo

## Adjuntos recomendados

Adjuntar solamente:

1. `tesis_draft_expandido.pdf` - borrador completo y autosuficiente.

No adjuntar inicialmente scripts, CSV, figuras sueltas, el archivo de datos, la bitácora ni la versión oficial. Incluir el enlace del repositorio en el cuerpo del correo solo como respaldo de reproducibilidad. Enviar materiales adicionales únicamente si la asesora los solicita.
