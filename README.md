geom_inner_rect
===============

PL/pgSQL function which computes a large inner rectangle of a PostGIS polygon geometry.

Installation:

```
$ psql -f geom_inner_rect.sql 
psql:geom_inner_rect.sql:6: NOTICE:  function geom_inner_rect(geometry) does not exist, skipping
DROP FUNCTION
CREATE FUNCTION
```


Usage:

```
dfuhry=> select geom_inner_rect('POLYGON((1 0, 2 1, 1 2, 0 1, 1 0))'::geometry);
                              geom_inner_rect                              
---------------------------------------------------------------------------
 (1.49243968554219,1.50700175183374),(0.507754748442597,0.492533641659065)
(1 row)
```

For higher accuracy, specify a larger number of iterations as the second parameter (default is 100).

```
dfuhry=> select geom_inner_rect('POLYGON((1 0, 2 1, 1 2, 0 1, 1 0))'::geometry, 10000);
                              geom_inner_rect                              
---------------------------------------------------------------------------
 (1.50044608594908,1.49947413915652),(0.499872432132179,0.500930010211853)
(1 row)
```

