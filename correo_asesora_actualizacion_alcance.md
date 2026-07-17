# Correo a la asesora: actualización de alcance y nuevo borrador

**Asunto:** Actualización del alcance y envío del nuevo borrador de tesis

Estimada profesora Felícita:

Espero que se encuentre muy bien. Le envío una versión profundamente revisada de la tesis. Quisiera resumir los cambios principales respecto de la versión oficial de Seminario 2, porque la ampliación y verificación del ejercicio empírico modificaron la conclusión predictiva y, con ello, el énfasis de la investigación.

La versión oficial trabajaba con 128 jornadas hasta julio de 2025 y concentraba el backtest principalmente en USD/PEN. Sus resultados sugerían que ARHinc podía mejorar la persistencia en los horizontes de cinco y diez días. La versión actual utiliza 299 superficies completas para cada uno de ocho pares, hasta marzo de 2026, y reestima todo el ejercicio con ventanas móviles. Bajo esta muestra, la persistencia cruda sobre la malla observada (PM) obtiene el menor RMSE mediano en los ocho pares y los tres horizontes.

Por ello, el nuevo argumento separa dos resultados:

- **Éxito descriptivo:** las B-splines tensoriales y la FPCA representan y comprimen eficazmente las superficies. En todos los pares, una o dos componentes explican al menos 95% de la variación funcional.
- **Resultado predictivo:** los modelos dinámicos en puntajes no mejoran sistemáticamente a PM bajo el backtest y las pérdidas evaluadas. La hipótesis predictiva se rechaza en lugar de conservar una conclusión favorable que no se sostiene con la muestra completa.

Considero que esta reformulación fortalece la tesis. La contribución ya no depende de que un modelo complejo gane, sino de distinguir rigurosamente entre capacidad de representación y valor predictivo incremental frente a un benchmark fuerte.

## Dos precisiones metodológicas

Quisiera destacar dos decisiones que ya aparecían en la versión oficial, pero que ahora se explican paso a paso y se conectan con la implementación final.

La primera es la **corrección Gram--Cholesky**. Como la base B-spline tensorial no es ortonormal, una PCA euclidiana directa sobre sus coeficientes no preservaría las distancias L² entre superficies. Se construye entonces la matriz de Gram, se factoriza como G = S' S y se transforman los coeficientes antes de aplicar PCA. Así, las varianzas, puntajes y eigensuperficies corresponden a la geometría funcional y no a una métrica arbitraria de los coeficientes.

La segunda es la **adaptación del modelo de regresión kernel con errores ARH(1) desarrollado en su artículo con Ruiz-Medina y Espejo (2019)**. La tesis conserva la estructura conceptual del modelo, pero la estima sobre los puntajes FPCA y no directamente sobre toda la superficie. Primero se proyecta cada superficie en K0 puntajes; luego se estima una media condicional kernel y una dinámica ARH(1) regularizada para sus residuos; finalmente, los puntajes pronosticados se reconstruyen como superficie.

Esta adaptación reduce la dimensión y vuelve viable la reestimación en ventanas móviles relativamente cortas. También permite comparar KernelARH, VAR1 y ARHinc bajo el mismo sistema de coordenadas. El borrador declara expresamente la contrapartida: se trata de una operacionalización truncada en puntajes, inspirada en el modelo funcional del artículo, y no de una implementación directa sobre todo el espacio de superficies.

## Flujo de trabajo final

El procedimiento queda organizado de la siguiente manera:

1. Construcción de las 299 superficies completas de 65 nodos para cada uno de los ocho pares.
2. Ajuste diario mediante base B-spline tensorial y diagnóstico del error de reconstrucción.
3. FPCA con corrección Gram--Cholesky, cálculo de eigensuperficies, puntajes y varianza explicada.
4. FPCA rolling para estudiar dimensión local y rotación de los factores.
5. Backtest móvil de PM, PA, VAR1, ARHinc y KernelARH en horizontes de uno, cinco y diez días.
6. Evaluación mediante RMSE, MAE, pérdidas ponderadas, tasas de acierto, pruebas de Diebold--Mariano y diagnósticos de estabilidad.
7. Robustez frente a distintas resoluciones de la base B-spline.

La metodología incluye ocho algoritmos descritos paso a paso y un apéndice que relaciona cada procedimiento con sus funciones y salidas. Esto responde directamente a la recomendación del jurado de explicar no solo qué algoritmo se usa, sino cómo se ejecuta dentro del estudio.

## Nuevo capítulo de simulación

La incorporación más importante respecto de la versión oficial es un capítulo completo de simulación Monte Carlo. Este capítulo no existía anteriormente y responde a una preocupación concreta: si PM domina en los datos reales, ¿se debe a la persistencia de las superficies o el pipeline de FPCA y reconstrucción favorece mecánicamente a PM?

La simulación genera superficies sobre la misma malla empírica mediante tres factores conocidos de nivel, inclinación y curvatura. Se consideran tres escenarios: alta persistencia, baja persistencia y cambio de régimen. La corrida final utiliza 1000 replicaciones por escenario, T=220, ventana de 80 observaciones, K0=3 y los mismos cinco modelos del backtest.

Los resultados cambian de manera coherente con el proceso generador. En alta persistencia, PM gana 100% de las replicaciones a un período, 97.5% a cinco y 74.2% a diez. En baja persistencia, PM no gana ninguna replicación y las victorias se trasladan principalmente a KernelARH y VAR1. Bajo cambio de régimen, PM prácticamente desaparece del primer lugar y el ganador se reparte entre los modelos dinámicos.

Por tanto, la dominancia empírica de PM no está impuesta por construcción: el mismo pipeline favorece modelos dinámicos cuando la dinámica verdadera contiene señal explotable. La simulación no pretende identificar el proceso generador de los datos reales; su función es validar que el procedimiento puede producir una conclusión distinta bajo condiciones conocidas.

## Otras ampliaciones

El nuevo borrador también incorpora el análisis individual de los ocho pares, trayectorias de puntajes FPCA, FPCA rolling, robustez por pérdida y base, diagnósticos de estabilidad, una visualización tridimensional del ajuste y una discusión más extensa de limitaciones. La bibliografía fue auditada y contiene 44 referencias citadas y verificadas. La versión actual tiene 73 páginas frente a las 45 de la versión oficial, principalmente por el detalle metodológico, la simulación y la comparación multimoneda.

También se explicitan dos límites importantes. Cada pronóstico se estima sin información futura, pero la selección global de ventana y K0 no constituye una validación completamente anidada con un bloque final reservado. Asimismo, la evaluación principal se realiza sobre la malla observada y la representación no impone restricciones de no arbitraje o positividad en todo el dominio continuo.

## Puntos sobre los que agradecería su orientación

1. Si considera adecuada la reformulación entre éxito descriptivo y resultado predictivo.
2. Si el capítulo de simulación debe permanecer en el cuerpo principal o pasar parcialmente a un anexo.
3. Si el análisis individual de los ocho pares debe mantenerse completo o resumirse en el cuerpo.
4. Si el título y la estructura general reflejan adecuadamente el alcance final.

Adjunto únicamente el nuevo PDF para que la revisión no requiera navegar scripts, CSV o figuras por separado. El código y las salidas reproducibles están disponibles en el repositorio si necesita revisar algún elemento específico.

Muchas gracias por su tiempo y por las observaciones de la asesoría y del jurado. Procuré preservar el nivel de detalle de la versión oficial, explicar cada algoritmo paso a paso y presentar con transparencia el cambio en la conclusión empírica.

Saludos cordiales,

Henri Camayo

## Adjuntos recomendados

Adjuntar solamente:

1. `tesis_draft_expandido.pdf` - borrador completo y autosuficiente.

No adjuntar inicialmente scripts, CSV, figuras sueltas, datos, bitácora ni la versión oficial. Incluir el enlace del repositorio únicamente como respaldo de reproducibilidad.
