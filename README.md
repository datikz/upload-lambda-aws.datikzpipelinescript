
# Script para subir a AWS lambda functions

Realiza la gestión de configurar y subir las funciones lambda según los casos de uso documentados y programados


## Pseudocodigo

~~~
- Eliminar posibles funciones relacionadas desactualizadas
- Leer metadata
- Existe función con el mismo nombre?

    NO:
    - Crear nueva función lambda con toda la configuración requerida

    SI:
    - Actualizar información de la metadata
- Obtener identificador
- Agregar tags
~~~