# 🚩 Sistema genérico de feature flags

## 🎯 Objetivo

El sistema de feature flags permite habilitar o deshabilitar funcionalidades de forma declarativa según:

- distribuidor;
- cliente;
- usuario;
- hostname;
- cookie;
- combinaciones de los criterios anteriores;
- exclusiones explícitas;
- activación global.

La configuración debe vivir en un solo lugar:

```text
qa/commons/App/Features/Config/features.php
```

El código que consume una feature sólo debe preguntar si está activa. No debe volver a implementar listas de IDs, validaciones de sesión, hostnames o cookies.

> ✅ **Idea principal:** las reglas viven en `features.php`; PHP y JavaScript solamente consultan el resultado.

## 🚀 Inicio rápido

Para crear y utilizar una feature nueva:

1. Declara sus reglas en `qa/commons/App/Features/Config/features.php`.
2. En PHP consulta `Feature::enabled('NOMBRE_FEATURE')`.
3. En JavaScript consulta `SelfUtils.featureEnabled('NOMBRE_FEATURE')`.
4. Conserva el comportamiento actual cuando la feature devuelva `false`.
5. Prueba un caso permitido y otro no permitido antes de liberar el cambio.

Ejemplo mínimo:

```php
// features.php
'NUEVO_FLUJO' => [
    'docs' => [
        'description' => 'Habilita el nuevo flujo de ejemplo.',
        'url' => null,
    ],
    'include' => [
        [
            'distribuidores' => [
                38875,
            ],
        ],
    ],
],
```

```php
if (\App\Features\Feature::enabled('NUEVO_FLUJO')) {
    ejecutarNuevoFlujo();
} else {
    ejecutarFlujoActual();
}
```

> ⚠️ **Regla de seguridad:** una feature flag controla un despliegue, no reemplaza permisos, autenticación ni autorización.

## 🧩 Arquitectura

```text
features.php
    │
    ▼
Feature
    │
    ▼
FeatureManager
    │
    ▼
FeatureContextResolver
    ├── DatosPlataformaHelper
    ├── HTTP_HOST
    └── cookies de la petición

Backend PHP
    └── Feature::enabled() / Feature::value()

Frontend JavaScript
    └── FeatureBootstrap → window.AppFeatures → SelfUtils.featureEnabled()
```

Los componentes se encuentran en:

- `qa/commons/App/Features/Feature.php`: API pública para PHP.
- `qa/commons/App/Features/FeatureManager.php`: evaluación de reglas.
- `qa/commons/App/Features/FeatureContext.php`: datos utilizados durante la evaluación.
- `qa/commons/App/Features/FeatureContextResolver.php`: obtiene distribuidor, cliente, usuario, hostname y cookies.
- `qa/commons/App/Features/FeatureBootstrap.php`: publica una vez las features al inicio del documento HTML.
- `qa/commons/App/Features/Config/features.php`: definiciones de las features.
- `qa/commons/media/js/self_utils.js`: permite consultar las features desde JavaScript.

## 🐘 API para PHP

### ✅ `Feature::enabled()`

Devuelve un booleano:

```php
if (\App\Features\Feature::enabled('MEJORA_TIPO_COMANDO')) {
    // Código nuevo
} else {
    // Comportamiento normal
}
```

Resultados posibles:

```php
true
false
```

Es la opción recomendada para condiciones y decisiones internas.

### 🔢 `Feature::value()`

Evalúa exactamente las mismas reglas, pero devuelve un entero:

```php
$data['mejora_bloqueo_mapa'] = \App\Features\Feature::value('MEJORA_BLOQUEO_MAPA');
```

Resultados posibles:

```php
1
0
```

Debe utilizarse cuando un arreglo, plantilla, JSON o integración requiera específicamente `1` o `0`, o cuando sea necesario preservar un contrato anterior.

### 📦 `Feature::all()`

Devuelve todas las features configuradas con su valor booleano para el contexto actual:

```php
[
    'MEJORA_TIPO_COMANDO' => true,
    'MEJORA_BLOQUEO_MAPA' => false,
]
```

`FeatureBootstrap` utiliza este método una sola vez por petición para construir `window.AppFeatures`.

### ¿Qué método PHP debo usar?

| Necesidad | Método | Resultado |
|---|---|---|
| Condición o decisión interna | `Feature::enabled()` | `true` o `false` |
| Contrato que exige enteros | `Feature::value()` | `1` o `0` |
| Publicar el conjunto de features | `Feature::all()` | Arreglo de booleanos |

## 🌐 API para JavaScript

En el frontend se debe utilizar exclusivamente la consulta genérica:

```javascript
if (SelfUtils.featureEnabled('MEJORA_TIPO_COMANDO')) {
    // Código nuevo
} else {
    // Comportamiento normal
}
```

`SelfUtils.featureEnabled()` no contiene reglas de negocio. Sólo consulta el valor booleano publicado por el backend:

```javascript
window.AppFeatures[nombre] === true
```

El bootstrap se inserta antes de los demás scripts desde los controladores base de las plataformas. Esto permite consultar features desde el login y evita depender de que `/SystemConfig/` haya terminado de cargar. La variable `window.AppFeaturesReady` permite distinguir entre un bootstrap completado y una configuración ausente.

No se deben agregar métodos como estos:

```javascript
SelfUtils.mejoraTipoComando()
SelfUtils.habilitarMapaParaDistribuidores()
```

Tampoco deben agregarse listas de distribuidores, clientes, usuarios, hosts o cookies en JavaScript. Las reglas pertenecen a `features.php`.

> ✅ `SelfUtils.featureEnabled()` sí forma parte del diseño correcto. Lo que debe evitarse es crear un método nuevo dentro de `SelfUtils` por cada feature.

## ⚙️ Reglas de evaluación

La evaluación sigue este orden:

1. Si la feature no existe, devuelve `false`.
2. Si coincide con cualquier grupo de `exclude`, devuelve `false`.
3. Si tiene `'all' => true`, devuelve `true`.
4. Si no tiene reglas `include`, devuelve `false`.
5. Si coincide con cualquier grupo de `include`, devuelve `true`.
6. En cualquier otro caso, devuelve `false`.

### 🔀 OR entre grupos

Cada elemento dentro de `include` es una alternativa. Basta con que uno coincida:

```php
'MI_FEATURE' => [
    'include' => [
        [
            'distribuidores' => [
                38875,
            ],
        ],
        [
            'clientes' => [
                12345,
            ],
        ],
    ],
],
```

La feature queda activa para el distribuidor `38875` **o** para el cliente `12345`.

### 🔗 AND dentro de un grupo

Los criterios declarados dentro del mismo grupo deben cumplirse simultáneamente:

```php
'MI_FEATURE' => [
    'include' => [
        [
            'distribuidores' => [
                485,
            ],
            'usuarios' => [
                236,
            ],
        ],
    ],
],
```

La feature sólo queda activa cuando el distribuidor es `485` **y** el usuario es `236`.

### Resumen visual de precedencia

```text
Feature inexistente ───────────────► false
        │
        ▼
¿Coincide con exclude? ── Sí ─────► false
        │ No
        ▼
¿Tiene all = true? ────── Sí ─────► true
        │ No
        ▼
¿Coincide algún include? ─ Sí ────► true
        │ No
        ▼
                                      false
```

> 🛑 **`exclude` siempre gana:** una cookie, un hostname o un distribuidor incluido no pueden reactivar una feature excluida.

## 🧰 Configuraciones disponibles

> ✅ `distribuidores`, `clientes`, `usuarios`, `hostnames` y `cookies` siempre se escriben como listas simples.

Al crear `FeatureManager`, las listas se validan y se convierten una sola vez en conjuntos internos optimizados. Por ejemplo:

```php
[
    1510,
    1510,
    38875,
]
```

se convierte internamente en el equivalente de:

```php
[
    1510 => true,
    38875 => true,
]
```

Esto permite una configuración breve, elimina duplicados y conserva las búsquedas directas por llave. El formato interno no debe escribirse manualmente en `features.php`.

### 📚 Metadatos de documentación

Cada feature puede incluir una llave `docs` con información para los desarrolladores:

```php
'MI_FEATURE' => [
    'docs' => [
        'description' => 'Explica qué problema resuelve la feature.',
        'url' => 'https://documentacion.example.com/solicitud',
    ],
    'all' => true,
],
```

`docs` no participa en la evaluación, no cambia el resultado y no se publica mediante `Feature::all()`. Se recomienda incluir:

- `description`: descripción breve del objetivo y comportamiento;
- `url`: enlace a la solicitud, ticket, diseño o documentación en línea;
- cualquier otro dato útil, como responsable o fecha, si el equipo lo necesita.

Cuando todavía no existe un enlace se puede utilizar:

```php
'url' => null,
```

### 🌎 Activación para todos

```php
'MI_FEATURE' => [
    'all' => true,
],
```

No se debe combinar `all` con un `include` de hostnames esperando limitar la feature. `all` la habilita para todos, salvo las exclusiones configuradas.

### 🏢 Por distribuidor

```php
'MI_FEATURE' => [
    'include' => [
        [
            'distribuidores' => [
                38875,
                37344,
            ],
        ],
    ],
],
```

Los IDs se escriben como una lista simple. `FeatureManager` elimina duplicados y convierte internamente la lista en un conjunto optimizado para búsquedas.


### 👥 Por cliente

```php
'MI_FEATURE' => [
    'include' => [
        [
            'clientes' => [
                155,
                12865,
            ],
        ],
    ],
],
```

### 👤 Por usuario

```php
'MI_FEATURE' => [
    'include' => [
        [
            'usuarios' => [
                26613,
                40001,
            ],
        ],
    ],
],
```

### 🌐 Por hostname

```php
'MI_FEATURE' => [
    'include' => [
        [
            'hostnames' => [
                'qa.service24gps.com',
                'platform-eu.redgps.com',
            ],
        ],
    ],
],
```

El hostname se obtiene de:

```php
$_SERVER['HTTP_HOST']
```

La comparación es exacta contra las llaves de `hostnames`.

- En un hostname permitido, la feature devuelve `true`.
- En cualquier otro hostname, devuelve `false`.
- Si `HTTP_HOST` no existe, el contexto utiliza `unknown` y la feature queda desactivada, salvo que otra regla `include` coincida.
- Si `HTTP_HOST` incluye un puerto, por ejemplo `localhost:8080`, el puerto forma parte del valor y debe aparecer en la configuración.

Una feature limitada únicamente por hostname no afecta a los demás sitios. Fuera de los hosts permitidos continúa ejecutándose el comportamiento normal del sistema.

> ✅ **Comportamiento esperado:** si el host no está permitido y ninguna otra regla coincide, la feature devuelve `false`.

### 🍪 Por cookie

```php
'MI_FEATURE' => [
    'include' => [
        [
            'cookies' => [
                'MI_FEATURE_TEMPORAL',
            ],
        ],
    ],
],
```

La feature queda activa cuando la petición contiene la cookie y ésta no tiene un valor explícito de desactivación:

```php
$_COOKIE['MI_FEATURE_TEMPORAL']
```

La presencia de la cookie implica `true` por defecto. Todos estos ejemplos activan la feature:

```text
MI_FEATURE_TEMPORAL=
MI_FEATURE_TEMPORAL=true
MI_FEATURE_TEMPORAL=1
MI_FEATURE_TEMPORAL=enabled
MI_FEATURE_TEMPORAL=cualquier_otro_valor
```

Los siguientes valores la desactivan explícitamente, sin importar mayúsculas o espacios alrededor:

```text
0
false
disabled
off
no
```

Si la cookie no existe, el grupo de cookie no coincide y la feature permanece inactiva salvo que otra regla `include` coincida.

Una cookie puede establecerse temporalmente desde el navegador:

```javascript
document.cookie = 'MI_FEATURE_TEMPORAL=true; path=/; SameSite=Lax';
```

Para desactivarla explícitamente:

```javascript
document.cookie = 'MI_FEATURE_TEMPORAL=false; path=/; SameSite=Lax';
```

Para eliminarla:

```javascript
document.cookie = 'MI_FEATURE_TEMPORAL=; Max-Age=0; path=/';
```

La cookie se evalúa en la siguiente petición HTTP. Si la página ya cargó `window.AppFeatures`, cambiar la cookie no modifica ese objeto hasta recargar o realizar una nueva petición que vuelva a evaluar las features.

Las cookies son controladas por el cliente. Por esa razón:

- pueden utilizarse para pruebas, despliegues progresivos y validaciones temporales;
- no deben utilizarse para permisos, autenticación, autorización o protección de información;
- una feature sensible debe tener controles de seguridad independientes.

### 🌐🍪 Hostname o cookie

Para permitir el hostname normal y conservar una activación temporal mediante cookie, deben utilizarse dos grupos:

```php
'MI_FEATURE' => [
    'include' => [
        [
            'hostnames' => [
                'qa.service24gps.com',
            ],
        ],
        [
            'cookies' => [
                'MI_FEATURE_TEMPORAL',
            ],
        ],
    ],
],
```

El resultado es:

| Host permitido | Cookie habilitada | Resultado |
|---|---:|---:|
| Sí | No | Activa |
| Sí | Sí | Activa |
| No | Sí | Activa |
| No | No | Inactiva |

Esto preserva el patrón de activación por cookie utilizado por los hacks de `Profiler`, pero sólo para las cookies declaradas explícitamente.

Si hostname y cookie se colocan dentro del mismo grupo, la relación cambia a AND:

```php
'include' => [
    [
        'hostnames' => [
            'qa.service24gps.com',
        ],
        'cookies' => [
            'MI_FEATURE_TEMPORAL',
        ],
    ],
],
```

En ese caso se requieren tanto el hostname permitido como la cookie habilitada.

### 🏢🍪 Distribuidor o cookie

```php
'MI_FEATURE' => [
    'include' => [
        [
            'distribuidores' => [
                485,
                470,
            ],
        ],
        [
            'cookies' => [
                'MI_FEATURE_TEMPORAL',
            ],
        ],
    ],
],
```

Este formato reemplaza los hacks mixtos de `Profiler` sin repetir lógica PHP.

### ⛔ Exclusiones

```php
'MI_FEATURE' => [
    'all' => true,
    'exclude' => [
        [
            'usuarios' => [
                5000,
            ],
        ],
        [
            'hostnames' => [
                'sitio-bloqueado.example.com',
            ],
        ],
    ],
],
```

Las exclusiones se evalúan antes que `all` e `include`. Si una exclusión coincide, ninguna cookie u otra regla de inclusión puede reactivar la feature.

## ♻️ Grupos reutilizables de distribuidores

Los grupos compartidos se declaran una sola vez al inicio de `features.php`:

```php
$gruposDespliegue = [
    'QA_INTERNAL' => [
        485,
        4220,
        38875,
    ],
];
```

Después pueden utilizarse en varias features:

```php
'MI_FEATURE' => [
    'include' => [
        [
            'distribuidores' => $gruposDespliegue['QA_INTERNAL'],
        ],
    ],
],
```

Para combinar grupos se utiliza `array_merge()`:

```php
'distribuidores' => array_merge(
    $gruposDespliegue['QA_INTERNAL'],
    $gruposDespliegue['BETA_TESTERS']
),
```

Los IDs repetidos entre los grupos se eliminan durante la normalización interna. De esta forma, agregar o retirar un distribuidor del grupo no requiere modificar todas las features que lo utilizan.

## 🛡️ Hostnames y comportamiento normal

El motor ya cumple la regla de aislamiento por hostname:

```text
¿El hostname está permitido?
    Sí  → el grupo de hostname coincide.
    No  → ese grupo no coincide y se revisa la siguiente alternativa.
          Si ninguna alternativa coincide, la feature devuelve false.
```

Cuando la feature devuelve `false`, el consumidor debe mantener el funcionamiento normal mediante el `else` o la ruta existente:

```php
if (\App\Features\Feature::enabled('NUEVO_FLUJO')) {
    ejecutarNuevoFlujo();
} else {
    ejecutarFlujoActual();
}
```

Otra feature no activa ésta automáticamente. Si dos features deben ser alternativas, puede representarse la regla dentro de una sola definición o expresarse de forma explícita en el consumidor:

```php
if (
    \App\Features\Feature::enabled('NUEVO_FLUJO')
    || \App\Features\Feature::enabled('HABILITACION_TEMPORAL')
) {
    ejecutarNuevoFlujo();
}
```

`TODAS_LAS_MEJORAS` no tiene un tratamiento especial en el motor. Actualmente es una feature independiente y no habilita automáticamente las demás.

> 💡 **Importante:** otra feature no activa ésta por compartir hostname, cookie o distribuidor. Cada feature se evalúa de manera independiente.

## ✨ Ventajas frente a hacks en helpers

### 📍 Una sola fuente de verdad

Las reglas ya no quedan repartidas entre `UtilsHelper`, `Profiler`, controladores, plantillas y JavaScript.

### 🔄 Misma evaluación en backend y frontend

PHP calcula las features y JavaScript recibe los resultados. No es necesario mantener dos listas de IDs o reproducir la lógica de sesiones en el navegador.

### 🧹 Menos métodos específicos

No se necesita crear un método PHP o JavaScript por cada mejora. Todas utilizan la misma API:

```php
Feature::enabled('NOMBRE_FEATURE')
```

```javascript
SelfUtils.featureEnabled('NOMBRE_FEATURE')
```

### 🔒 Comportamiento seguro por defecto

Una feature inexistente, sin reglas o sin coincidencias devuelve `false`. El código nuevo no se activa accidentalmente.

### 📈 Despliegues progresivos

Una funcionalidad puede pasar gradualmente por:

1. cookie de desarrollo;
2. hostname de QA;
3. distribuidores beta;
4. grupo de producción;
5. activación global.

El código de la funcionalidad no cambia durante esas etapas; sólo cambia su configuración.

### 🔍 Reglas auditables

La configuración muestra claramente quién recibe una feature, qué exclusiones existen y qué mecanismos temporales pueden habilitarla.

### ♻️ Reutilización de grupos

Los distribuidores de QA, beta o producción pueden mantenerse en grupos compartidos sin duplicarlos en cada hack.

### 🗑️ Migración y eliminación más sencillas

Una vez liberada una feature para todos se puede configurar con `all`. Cuando el código anterior sea retirado, también puede eliminarse la condición y posteriormente la entrada de configuración.

## 🧭 Qué debe permanecer en `UtilsHelper` y `SelfUtils`

Los helpers siguen siendo apropiados para operaciones reutilizables, transformación de datos, formatos, cálculos o interacción con APIs.

No son el lugar adecuado para reglas de despliegue como:

```php
if (in_array($distribuidor, [485, 470, 38875])) {
    // Mejora temporal
}
```

`SelfUtils.featureEnabled()` sí debe permanecer: es el adaptador genérico del frontend. Lo que debe evitarse es agregar dentro de `SelfUtils` una función nueva por feature o duplicar en JavaScript las reglas declaradas en PHP.

### ✅ Correcto e incorrecto

| ✅ Correcto | ❌ Evitar |
|---|---|
| Reglas centralizadas en `features.php` | IDs repetidos en controladores y helpers |
| `Feature::enabled('NOMBRE_FEATURE')` en PHP | Un método PHP por cada feature |
| `SelfUtils.featureEnabled('NOMBRE_FEATURE')` en JavaScript | Reglas de rollout duplicadas en JavaScript |
| Mantener un camino normal cuando devuelve `false` | Asumir que la feature siempre estará activa |
| Usar cookies sólo para rollout o pruebas | Usar cookies como permisos de seguridad |

## 🆕 Proceso recomendado para crear una feature

1. Elegir un nombre descriptivo, estable, en `UPPER_SNAKE_CASE`.
2. Agregar la definición y sus metadatos `docs` en `features.php`.
3. Definir claramente el comportamiento normal cuando la feature esté desactivada.
4. Consultarla con `Feature::enabled()` en PHP o `SelfUtils.featureEnabled()` en JavaScript.
5. Probar al menos un contexto permitido y uno no permitido.
6. Si utiliza cookie, probar presencia, ausencia y un valor explícito de desactivación.
7. Si utiliza hostname, probar todos los hosts permitidos y al menos uno no permitido.
8. Verificar que la funcionalidad anterior continúe operando cuando el resultado sea `false`.

Ejemplo completo:

```php
'NUEVO_PANEL' => [
    'include' => [
        [
            'hostnames' => [
                'qa.service24gps.com',
            ],
        ],
        [
            'distribuidores' => [
                38875,
            ],
        ],
        [
            'cookies' => [
                'NUEVO_PANEL',
            ],
        ],
    ],
    'exclude' => [
        [
            'usuarios' => [
                5000,
            ],
        ],
    ],
],
```

La feature se activa por hostname, distribuidor o cookie, excepto para el usuario excluido.

## 🚚 Proceso recomendado para migrar un hack existente

1. Localizar todas las referencias al nombre del hack.
2. Identificar sus reglas efectivas: IDs, grupos, hostname, cookie y exclusiones.
3. Trasladar esas reglas a `features.php`.
4. Comparar el resultado del evaluador anterior y del nuevo con contextos representativos.
5. Reemplazar las referencias PHP por `Feature::enabled()` o `Feature::value()`.
6. Reemplazar las validaciones JavaScript por `SelfUtils.featureEnabled()`.
7. Confirmar que ya no existen referencias al helper anterior.
8. Eliminar el código obsoleto únicamente después de completar y validar la migración.

Durante la transición, `Profiler.php` y sus consumidores pueden permanecer sin cambios mientras las definiciones equivalentes se preparan en `features.php`.

## ⚠️ Consideraciones y límites

### 🔤 Los nombres deben estar en mayúsculas

Estos nombres son diferentes:

```text
MEJORA_CSP_LOGIN
mejora_csp_login
```

Las features configuradas con minúsculas provocan una excepción al construir `FeatureManager`. Las consultas realizadas con un nombre que contiene minúsculas devuelven `false`; el sistema no lo convierte automáticamente.

En JavaScript sucede lo mismo: `window.AppFeatures` sólo contiene las llaves uppercase configuradas, por lo que `SelfUtils.featureEnabled()` devuelve `false` si recibe otra capitalización.

La convención recomendada y utilizada por el proyecto es `UPPER_SNAKE_CASE`:

```text
MEJORA_TIPO_COMANDO
SESSION_MANAGER_COMPRESS
CONSUMO_STREAMING_REDGPS
```

Esto permite identificar fácilmente una feature flag y evita mezclar estilos históricos como camelCase, PascalCase o minúsculas.

También se recomienda nombrar las cookies nuevas en `UPPER_SNAKE_CASE`, preferentemente igual que la feature. Los alias de cookies históricas pueden conservarse temporalmente para no interrumpir pruebas existentes.

### 🧠 El contexto se conserva durante la ejecución

`FeatureContextResolver` conserva el contexto resuelto para evitar consultar repetidamente los datos de plataforma. Esto es adecuado para una petición web normal.

Un proceso CLI o worker de larga duración que cambie de usuario, cliente o distribuidor dentro del mismo proceso no debe reutilizar el contexto sin implementar primero un mecanismo explícito para reiniciarlo.

### 👁️ Las features del frontend son visibles

Los nombres y valores publicados en `window.AppFeatures` pueden ser inspeccionados por el usuario. No deben contener secretos ni sustituir validaciones del backend.

### 🔐 Hostname y cookies no son autorización

`HTTP_HOST` y las cookies forman parte del contexto de la petición. Son útiles para rollout, compatibilidad y pruebas, pero no reemplazan el sistema de permisos.

### 🚀 Los cambios requieren despliegue

La configuración vive en código PHP. Agregar o modificar una regla requiere desplegar el repositorio `commons` en los entornos que consumen esa versión.

Cuando el consumidor se encuentra en otro repositorio, por ejemplo `redgps` o `partners`, los cambios deben desplegarse de manera coordinada con `commons`.

## 🩺 Diagnóstico rápido

Si una feature no se activa:

1. Confirmar que el nombre existe exactamente en `features.php`.
2. Revisar si alguna regla `exclude` coincide.
3. Verificar los valores devueltos por `DatosPlataformaHelper::getInfoClienteUsuarioDistribuidor()`.
4. Comparar `$_SERVER['HTTP_HOST']` con las llaves configuradas, incluyendo un posible puerto.
5. Confirmar que la cookie existe y no contiene un valor explícito de desactivación.
6. En frontend, confirmar que `window.AppFeatures` fue cargado y contiene un booleano `true`.
7. Recargar la página después de crear o eliminar una cookie.

## 📋 Checklist antes de liberar

- [ ] La feature existe en `features.php` con el nombre exacto.
- [ ] `docs.description` explica el objetivo y `docs.url` enlaza la solicitud cuando existe.
- [ ] El camino normal funciona cuando la feature devuelve `false`.
- [ ] Se probó al menos un distribuidor, cliente, usuario o host permitido.
- [ ] Se probó al menos un contexto no permitido.
- [ ] Las cookies se probaron presentes, ausentes y con un valor explícito de desactivación.
- [ ] Las exclusiones tienen prioridad sobre las inclusiones.
- [ ] No se copiaron IDs ni reglas al frontend.
- [ ] No se utilizó la feature como sustituto de permisos.
- [ ] Si participan varios repositorios, el despliegue con `commons` está coordinado.
