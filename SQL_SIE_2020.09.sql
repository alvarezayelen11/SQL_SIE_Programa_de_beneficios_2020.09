USE sie;

/* Queremos conocer cuántos clientes tenemos y cuántos de ellos son miembros del programa de beneficios (activos e inactivos).
Además, queremos saber cuántos de los clientes que son miembros del programa de beneficios lo utilizan actualmente (son miembros activos) */

DESCRIBE clientes;
DESCRIBE miembros; 

SELECT 
(SELECT COUNT(id_cliente) FROM clientes) AS total_clientes,
(SELECT COUNT(CASE WHEN id_miembro IS NOT NULL THEN id_miembro END) FROM clientes) AS total_miembros,
(SELECT COUNT(CASE WHEN activo = 1 THEN activo END) FROM miembros) AS miembros_activos;

/* Queremos conocer el promedio y la mediana de la cantidad de puntos de los miembros activos. 
Por cuestiones propias del negocio, elegimos redondear el promedio y truncar la mediana.
Dado que el cálculo de la mediana no está definido en SQL y es un dato que necesitamos conocer periódicamente, generamos una Stored Procedure para su cálculo */

DELIMITER //
CREATE PROCEDURE calcular_mediana()
BEGIN
SELECT 
    TRUNCATE(AVG(cant_puntos), 0) AS mediana
FROM (
    SELECT cant_puntos
    FROM (
        SELECT cant_puntos, @rownum:=@rownum+1 AS posicion, @total_rows:=@rownum
        FROM (SELECT cant_puntos FROM miembros ORDER BY cant_puntos) AS sorted,
        (SELECT @rownum:=0) r
    ) AS ranked
    WHERE posicion IN (CEIL(@total_rows/2), FLOOR(@total_rows/2)+1)
) AS total_mediana;
END //
DELIMITER ;

SELECT ROUND(AVG(cant_puntos)) AS promedio_puntos
FROM miembros 
WHERE activo = 1;

CALL calcular_mediana(1);

/* Necesitamos agrupar a los clientes que son miembros activos del programa de beneficios en 3 segmentos, de acuerdo a la cantidad de puntos que poseen. 
Necesitamos saber cuántos clientes hay que cada segmento */

SELECT 
	(CASE WHEN cant_puntos = 0 THEN 'Cero'
	WHEN cant_puntos <=1000 THEN '1000 o menos'
	ELSE 'Mas de 1000'
END) AS clasificacion_puntos, 
COUNT(*) AS miembros_segun_puntos
FROM miembros 
WHERE activo = 1
GROUP BY 
CASE 
WHEN cant_puntos = 0 THEN 'Cero'
        WHEN cant_puntos <= 1000 THEN '1000 o menos'
        ELSE 'Mas de 1000'
    END
    ORDER BY
    FIELD(clasificacion_puntos, "Mas de 1000", "1000 o menos", "Cero");

/* Necesitamos conocer de qué provincias son los clientes miembros del programa de beneficios que canjearon recientemente sus puntos por mercadería, para poder gestionar los envíos de manera eficiente */

SELECT gestiones.id_gestion, 
clientes.id_cliente,
localidad.nombre AS localidad,
provincia.nombre AS provincia
FROM clientes
INNER JOIN gestiones
ON clientes.id_cliente = gestiones.num_cliente
INNER JOIN localidad
ON clientes.localidad = localidad.id_localidad
INNER JOIN provincia
ON localidad.provincia = provincia.id_provincia
ORDER BY provincia, localidad;

/* Tenemos que enviar un checklist al área de Logística, para que sepan cuántas órdenes tienen que enviar a cada provincia. Cada orden corresponde a una gestión */

SELECT provincia.nombre AS provincia, 
COUNT(*) AS cantidad_ordenes
FROM provincia
INNER JOIN localidad
ON provincia.id_provincia = localidad.provincia
INNER JOIN clientes
ON localidad.id_localidad = clientes.localidad
INNER JOIN gestiones
ON clientes.id_cliente = gestiones.num_cliente
GROUP BY provincia
ORDER BY cantidad_ordenes DESC;

/* Necesitamos conocer cuáles son los 5 productos más solicitados dentro del programa de beneficios. 
Para cerciorarnos de que los nombres de los productos no fueron cargados con espacios al principio y al final, vamos a usar primero la función TRIM.
Además, queremos saber si la plancha es un producto solicitado, ya que el área de Marketing está evaluando retirar este producto del programa de beneficios*/

SELECT TRIM(productos.nombre) AS producto, 
COUNT(*) AS cantidad_pedida
FROM productos
INNER JOIN gestiones
ON productos.id_producto = gestiones.id_producto
GROUP BY producto
ORDER BY cantidad_pedida DESC
LIMIT 5; 

SELECT TRIM(productos.nombre) AS producto,
COUNT(*) AS cantidad_pedida
FROM productos
INNER JOIN gestiones
ON productos.id_producto = gestiones.id_producto
WHERE EXISTS (
    SELECT 1
    FROM productos AS p
    INNER JOIN gestiones AS g
    ON p.id_producto = g.id_producto
    WHERE TRIM(p.nombre) = 'plancha' AND g.id_producto = productos.id_producto
)
GROUP BY producto;