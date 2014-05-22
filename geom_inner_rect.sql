-- geom_inner_rect.sql
-- Computes a large inner (axis-aligned) rectangle of a polygon geometry using monte carlo sampling and binary search.
-- Increasing "iterations" parameter from its default of 100 gives a better result at expense of longer running time.
-- Author: David Fuhry <dfuhry@gmail.com>

DROP FUNCTION IF EXISTS geom_inner_rect(geom geometry);
CREATE OR REPLACE FUNCTION geom_inner_rect(geom geometry, iterations integer DEFAULT 100) RETURNS box AS $$
DECLARE
  xmin double precision := st_xmin(geom);
  ymin double precision := st_ymin(geom);
  xmax double precision := st_xmax(geom);
  ymax double precision := st_ymax(geom);
  rect_minx double precision;
  rect_miny double precision;
  rect_maxx double precision;
  rect_maxy double precision;
  cur_xmid double precision;
  cur_ymid double precision;
  upright_maxx double precision;
  upright_maxy double precision;
  lowleft_minx double precision;
  lowleft_miny double precision;
  inner_rect box := NULL;
  mid_rect geometry;
  tmp_x double precision;
  tmp_y double precision;
  viable_inner_rect boolean;
  rand_pt_iters integer;
  grow_iters integer;
BEGIN

  FOR i IN 1 .. iterations LOOP
    -- Get two random inner points.
    rect_minx := NULL;
    rect_miny := NULL;
    rand_pt_iters := 0;
    WHILE rand_pt_iters < 1000 AND (rect_minx IS NULL OR rect_miny IS NULL OR NOT st_contains(geom, st_setsrid(st_makepoint(rect_minx, rect_miny), st_srid(geom)))) LOOP
      rand_pt_iters := rand_pt_iters + 1;
      rect_minx := xmin + (xmax - xmin) * random();
      rect_miny := ymin + (ymax - ymin) * random();
    END LOOP;
    IF rect_minx IS NULL THEN
      CONTINUE;
    END IF;
    rect_maxx := NULL;
    rect_maxy := NULL;
    rand_pt_iters := 0;
    WHILE rand_pt_iters < 1000 AND (rect_maxx IS NULL OR rect_maxy IS NULL OR NOT st_contains(geom, st_setsrid(st_makepoint(rect_maxx, rect_maxy), st_srid(geom)))) LOOP
      rand_pt_iters := rand_pt_iters + 1;
      rect_maxx := xmin + (xmax - xmin) * random();
      rect_maxy := ymin + (ymax - ymin) * random();
    END LOOP;
    IF rect_maxx IS NULL THEN
      CONTINUE;
    END IF;
    -- Swap x and y points if min & max are wrong.
    IF rect_maxx < rect_minx THEN
      tmp_x := rect_maxx;
      rect_maxx := rect_minx;
      rect_minx := tmp_x;
    END IF;
    IF rect_maxy < rect_miny THEN
      tmp_y := rect_maxy;
      rect_maxy := rect_miny;
      rect_miny := tmp_y;
    END IF;


    IF st_contains(geom, st_makeenvelope(rect_minx, rect_miny, rect_maxx, rect_maxy, st_srid(geom))) THEN
      -- Grow upper-right coordinate proportionally.
      viable_inner_rect := True;
      upright_maxx := xmax;
      upright_maxy := ymax;
      grow_iters := 0;
      WHILE grow_iters < 1000 AND viable_inner_rect AND (upright_maxx - rect_maxx) > 0.001 LOOP
        grow_iters := grow_iters + 1;
        cur_xmid := rect_maxx + (upright_maxx - rect_maxx) / 2.0;
        cur_ymid := rect_maxy + (upright_maxy - rect_maxy) / 2.0;
        mid_rect := st_makeenvelope(rect_minx, rect_miny, cur_xmid, cur_ymid, st_srid(geom));
        IF st_contains(geom, mid_rect) THEN
          rect_maxx := cur_xmid;
          rect_maxy := cur_ymid;
          IF inner_rect IS NULL OR area(mid_rect::box) > area(inner_rect) THEN
            inner_rect := mid_rect::box;
          END IF;
        ELSE
          upright_maxx := cur_xmid;
          upright_maxy := cur_ymid;
          IF area(mid_rect::box) < area(inner_rect) THEN
            viable_inner_rect := False;
          END IF;
        END IF;
      END LOOP;

      -- Grow right x.
      viable_inner_rect := True;
      upright_maxx := xmax;
      grow_iters := 0;
      WHILE grow_iters < 1000 AND viable_inner_rect AND (upright_maxx - rect_maxx) > 0.001 LOOP
        grow_iters := grow_iters + 1;
        cur_xmid := rect_maxx + (upright_maxx - rect_maxx) / 2.0;
        mid_rect := st_makeenvelope(rect_minx, rect_miny, cur_xmid, rect_maxy, st_srid(geom));
        IF st_contains(geom, mid_rect) THEN
          rect_maxx := cur_xmid;
          IF inner_rect IS NULL OR area(mid_rect::box) > area(inner_rect) THEN
            inner_rect := mid_rect::box;
          END IF;
        ELSE
          upright_maxx := cur_xmid;
          IF area(mid_rect::box) < area(inner_rect) THEN
            viable_inner_rect := False;
          END IF;
        END IF;
      END LOOP;

      -- Grow top y.
      viable_inner_rect := True;
      upright_maxy := ymax;
      grow_iters := 0;
      WHILE grow_iters < 1000 AND viable_inner_rect AND (upright_maxy - rect_maxy) > 0.001 LOOP
        grow_iters := grow_iters + 1;
        cur_ymid := rect_maxy + (upright_maxy - rect_maxy) / 2.0;
        mid_rect := st_makeenvelope(rect_minx, rect_miny, rect_maxx, cur_ymid, st_srid(geom));
        IF st_contains(geom, mid_rect) THEN
          rect_maxy := cur_ymid;
          IF inner_rect IS NULL OR area(mid_rect::box) > area(inner_rect) THEN
            inner_rect := mid_rect::box;
          END IF;
        ELSE
          upright_maxy := cur_ymid;
          IF area(mid_rect::box) < area(inner_rect) THEN
            viable_inner_rect := False;
          END IF;
        END IF;
      END LOOP;

      -- Grow lower-left coordinate proportionally.
      viable_inner_rect := True;
      lowleft_minx := xmin;
      lowleft_miny := ymin;
      grow_iters := 0;
      WHILE grow_iters < 1000 AND viable_inner_rect AND (rect_minx - lowleft_minx) > 0.001 LOOP
        grow_iters := grow_iters + 1;
        cur_xmid := lowleft_minx + (rect_minx - lowleft_minx) / 2.0;
        cur_ymid := lowleft_miny + (rect_miny - lowleft_miny) / 2.0;
        mid_rect := st_makeenvelope(cur_xmid, cur_ymid, rect_maxx, rect_maxy, st_srid(geom));
        IF st_contains(geom, mid_rect) THEN
          rect_minx := cur_xmid;
          rect_miny := cur_ymid;
          IF inner_rect IS NULL OR area(mid_rect::box) > area(inner_rect) THEN
            inner_rect := mid_rect::box;
          END IF;
        ELSE
          lowleft_minx := cur_xmid;
          lowleft_miny := cur_ymid;
          IF area(mid_rect::box) < area(inner_rect) THEN
            viable_inner_rect := False;
          END IF;
        END IF;
      END LOOP;

      -- Grow left x.
      viable_inner_rect := True;
      lowleft_minx := xmin;
      grow_iters := 0;
      WHILE grow_iters < 1000 AND viable_inner_rect AND (rect_minx - lowleft_minx) > 0.001 LOOP
        grow_iters := grow_iters + 1;
        cur_xmid := lowleft_minx + (rect_minx - lowleft_minx) / 2.0;
        mid_rect := st_makeenvelope(cur_xmid, rect_miny, rect_maxx, rect_maxy, st_srid(geom));
        IF st_contains(geom, mid_rect) THEN
          rect_minx := cur_xmid;
          IF inner_rect IS NULL OR area(mid_rect::box) > area(inner_rect) THEN
            inner_rect := mid_rect::box;
          END IF;
        ELSE
          lowleft_minx := cur_xmid;
          IF area(mid_rect::box) < area(inner_rect) THEN
            viable_inner_rect := False;
          END IF;
        END IF;
      END LOOP;

      -- Grow bottom y.
      viable_inner_rect := True;
      lowleft_miny := ymin;
      grow_iters := 0;
      WHILE viable_inner_rect AND (rect_miny - lowleft_miny) > 0.001 LOOP
        grow_iters := grow_iters + 1;
        cur_ymid := lowleft_miny + (rect_miny - lowleft_miny) / 2.0;
        mid_rect := st_makeenvelope(rect_minx, cur_ymid, rect_maxx, rect_maxy, st_srid(geom));
        IF st_contains(geom, mid_rect) THEN
          rect_miny := cur_ymid;
          IF inner_rect IS NULL OR area(mid_rect::box) > area(inner_rect) THEN
            inner_rect := mid_rect::box;
          END IF;
        ELSE
          lowleft_miny := cur_ymid;
          IF area(mid_rect::box) < area(inner_rect) THEN
            viable_inner_rect := False;
          END IF;
        END IF;
      END LOOP;

    END IF;

  END LOOP;

  --RAISE NOTICE 'max_dist %, cur_max %, cur_min %, cur_mid %', max_dist, cur_max, cur_min, cur_mid;
  RETURN inner_rect;
END;
$$ LANGUAGE plpgsql STRICT IMMUTABLE;
