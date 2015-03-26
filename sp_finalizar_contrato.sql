DELIMITER $$

DROP PROCEDURE IF EXISTS `bd_alquiler`.`sp_finalizar_contrato` $$
CREATE PROCEDURE `bd_alquiler`.`sp_finalizar_contrato` (
in id_usuario_i int,
in ip varchar(16),
in nav varchar(50),
in so varchar(50),
in id_contrato_i int,
in presupuesto_i decimal(10,2),
in observacion_i varchar(200),
in fecha_fin_i timestamp,
out salida varchar(10)
)
BEGIN

DECLARE done INT DEFAULT FALSE; -- estado del cursor
DECLARE id_det,id_vh,id_art int;

-- cursor
-- los detalles del contrato cuyo estado sea ACTiVO = A
DECLARE cur_detalle CURSOR FOR
SELECT id_detallealquiler, id_vehiculo, id_articulo FROM detallealquiler
WHERE id_contrato = id_contrato_i AND est_alq = 'A';

-- Declaración de un manejador de error tipo NOT FOUND
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

-- handler para Transaccion
DECLARE EXIT HANDLER FOR SQLEXCEPTION
BEGIN
  ROLLBACK;
END;

-- inicio de transaccion
START TRANSACTION;

-- apertura de cursor
OPEN cur_detalle;

-- bucle de lectura del cursor
read_loop: LOOP

  FETCH cur_detalle INTO id_det,id_vh,id_art; -- asigno cada clave

  IF done THEN
    LEAVE read_loop;
  END IF;

  -- MODIFICACION DE TABLAS
  -- cambia estado a vehiculos
  UPDATE vehiculo SET estado = 'D' WHERE id_vehiculo = id_vh;
  -- cambia estado a artculo
  UPDATE articulo SET estado = 'D' WHERE id_articulo = id_art;
  -- cambia estado a detallealquiler
  UPDATE detallealquiler SET est_alq = 'B' WHERE id_detallealquiler = id_det;
  -- cambia estado a trabvehiculo
  UPDATE trabvehiculo SET f_fin = fecha_fin_i, estado = 'B' WHERE id_detallealquiler = id_det AND estado = 'A';
  -- registrar en tbl devolucion
  INSERT INTO devolucion VALUES(NULL,id_det,fecha_fin_i,'','FINALIZACIÓN DE CONTRARO');

END LOOP;

CLOSE cur_detalle;

-- obtiene la obra
SET @obra = (SELECT id_obra FROM contrato WHERE id_contrato = id_contrato_i);

-- cambia estado a obra
UPDATE obra SET estado = 'B' WHERE id_obra = @obra;

-- datos de contrato
UPDATE contrato SET f_fin = fecha_fin_i, presupuesto = ifnull(presupuesto_i,0), detalle = observacion_i, estado = 'B'
WHERE id_contrato = id_contrato_i;

-- verifica cambios
SET @val = (SELECT count(*) FROM contrato WHERE id_contrato = id_contrato_i AND f_fin = fecha_fin_i);

if (@val = 1) then
  COMMIT;
  SET salida = 'OK';
  CALL sp_regs(id_usuario_i,concat('FINALIZACIÓN DEL CONTRATO: ',id_contrato_i),
  'vehiculo,articulo,detallealquiler,trabvehiculo,devolucion,obra,contrato',ip,nav,so);
else
  ROLLBACK;
end if;

END $$

DELIMITER ;
