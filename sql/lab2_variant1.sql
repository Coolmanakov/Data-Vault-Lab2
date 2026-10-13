-- ЛР 2, вариант 1. PostgreSQL 14+. Выполнять в отдельной учебной БД.
-- Существующие схемы не удаляются. Повторный запуск всего файла требует чистой БД.
BEGIN;
CREATE SCHEMA exam_3nf;
CREATE SCHEMA exam_dv;

CREATE TABLE exam_3nf.student (
  student_id bigint PRIMARY KEY,
  student_code text NOT NULL UNIQUE,
  full_name text NOT NULL
);

CREATE TABLE exam_3nf.discipline (
  discipline_id bigint PRIMARY KEY,
  discipline_code text NOT NULL UNIQUE,
  name text NOT NULL
);

CREATE TABLE exam_3nf.topic (
  topic_id bigint PRIMARY KEY,
  topic_code text NOT NULL UNIQUE,
  discipline_id bigint NOT NULL REFERENCES exam_3nf.discipline,
  title text NOT NULL
);

CREATE TABLE exam_3nf.material (
  material_id bigint PRIMARY KEY,
  material_code text NOT NULL UNIQUE,
  title text NOT NULL,
  url text NOT NULL
);

CREATE TABLE exam_3nf.topic_material (
  topic_id bigint REFERENCES exam_3nf.topic,
  material_id bigint REFERENCES exam_3nf.material,
  PRIMARY KEY(topic_id, material_id)
);

CREATE TABLE exam_3nf.exam (
  exam_id bigint PRIMARY KEY,
  exam_code text NOT NULL UNIQUE,
  discipline_id bigint NOT NULL REFERENCES exam_3nf.discipline,
  exam_date date NOT NULL
);

CREATE TABLE exam_3nf.preparation (
  preparation_id bigint PRIMARY KEY,
  student_id bigint NOT NULL REFERENCES exam_3nf.student,
  exam_id bigint NOT NULL REFERENCES exam_3nf.exam,
  start_date date NOT NULL,
  target_grade smallint NOT NULL DEFAULT 5 CHECK(target_grade = 5),
  UNIQUE(student_id, exam_id)
);

CREATE TABLE exam_3nf.study_session (
  session_id bigint PRIMARY KEY,
  session_code text NOT NULL UNIQUE,
  preparation_id bigint NOT NULL REFERENCES exam_3nf.preparation,
  topic_id bigint NOT NULL REFERENCES exam_3nf.topic,
  planned_at timestamptz NOT NULL,
  completed_at timestamptz,
  duration_minutes integer NOT NULL CHECK(duration_minutes > 0),
  status text NOT NULL CHECK(status IN ('planned','done','cancelled')),
  CHECK((status = 'done') = (completed_at IS NOT NULL))
);

CREATE TABLE exam_3nf.self_check (
  check_id bigint PRIMARY KEY,
  check_code text NOT NULL UNIQUE,
  preparation_id bigint NOT NULL REFERENCES exam_3nf.preparation,
  topic_id bigint NOT NULL REFERENCES exam_3nf.topic,
  checked_at timestamptz NOT NULL,
  score numeric(5,2) NOT NULL CHECK(score BETWEEN 0 AND 100)
);

CREATE TABLE exam_3nf.exam_result (
  preparation_id bigint PRIMARY KEY REFERENCES exam_3nf.preparation,
  actual_grade smallint NOT NULL CHECK(actual_grade BETWEEN 2 AND 5),
  recorded_at timestamptz NOT NULL
);

-- Контроль межтабличных правил: тема и экзамен относятся к одной дисциплине.
CREATE FUNCTION exam_3nf.validate_topic() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE d1 bigint; d2 bigint;
BEGIN
 SELECT t.discipline_id INTO d1 FROM exam_3nf.topic t WHERE t.topic_id=NEW.topic_id;
 SELECT e.discipline_id INTO d2 FROM exam_3nf.preparation p
 JOIN exam_3nf.exam e USING(exam_id) WHERE p.preparation_id=NEW.preparation_id;
 IF d1 IS DISTINCT FROM d2 THEN RAISE EXCEPTION 'Тема не относится к дисциплине экзамена'; END IF;
 RETURN NEW;
END; $$;
CREATE TRIGGER session_topic BEFORE INSERT OR UPDATE ON exam_3nf.study_session
 FOR EACH ROW EXECUTE FUNCTION exam_3nf.validate_topic();
CREATE TRIGGER check_topic BEFORE INSERT OR UPDATE ON exam_3nf.self_check
 FOR EACH ROW EXECUTE FUNCTION exam_3nf.validate_topic();
-- Родительские связи topic.discipline_id, exam.discipline_id и preparation.exam_id
-- после появления дочерних записей в учебном сценарии не изменяются.


CREATE TABLE exam_dv.hub_student (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_key text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.hub_discipline (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_key text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.hub_topic (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_key text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.hub_material (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_key text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.hub_exam (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  business_key text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.link_topic_discipline (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  topic_id bigint NOT NULL REFERENCES exam_dv.hub_topic,
  discipline_id bigint NOT NULL REFERENCES exam_dv.hub_discipline,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  UNIQUE(topic_id, discipline_id)
);

CREATE TABLE exam_dv.link_topic_material (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  topic_id bigint NOT NULL REFERENCES exam_dv.hub_topic,
  material_id bigint NOT NULL REFERENCES exam_dv.hub_material,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  UNIQUE(topic_id, material_id)
);

CREATE TABLE exam_dv.link_exam_discipline (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  exam_id bigint NOT NULL REFERENCES exam_dv.hub_exam,
  discipline_id bigint NOT NULL REFERENCES exam_dv.hub_discipline,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  UNIQUE(exam_id, discipline_id)
);

CREATE TABLE exam_dv.link_preparation (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id bigint NOT NULL REFERENCES exam_dv.hub_student,
  exam_id bigint NOT NULL REFERENCES exam_dv.hub_exam,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  UNIQUE(student_id, exam_id)
);

CREATE TABLE exam_dv.link_session (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id bigint NOT NULL REFERENCES exam_dv.hub_student,
  exam_id bigint NOT NULL REFERENCES exam_dv.hub_exam,
  topic_id bigint NOT NULL REFERENCES exam_dv.hub_topic,
  event_code text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.link_check (
  id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  student_id bigint NOT NULL REFERENCES exam_dv.hub_student,
  exam_id bigint NOT NULL REFERENCES exam_dv.hub_exam,
  topic_id bigint NOT NULL REFERENCES exam_dv.hub_topic,
  event_code text NOT NULL UNIQUE,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL
);

CREATE TABLE exam_dv.sat_student (
  parent_id bigint NOT NULL REFERENCES exam_dv.hub_student,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  full_name text NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_discipline (
  parent_id bigint NOT NULL REFERENCES exam_dv.hub_discipline,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  name text NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_topic (
  parent_id bigint NOT NULL REFERENCES exam_dv.hub_topic,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  title text NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_material (
  parent_id bigint NOT NULL REFERENCES exam_dv.hub_material,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  title text NOT NULL,
  url text NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_exam (
  parent_id bigint NOT NULL REFERENCES exam_dv.hub_exam,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  exam_date date NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_preparation (
  parent_id bigint NOT NULL REFERENCES exam_dv.link_preparation,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  start_date date NOT NULL,
  target_grade smallint NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_session (
  parent_id bigint NOT NULL REFERENCES exam_dv.link_session,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  planned_at timestamptz NOT NULL,
  completed_at timestamptz,
  duration_minutes integer NOT NULL,
  status text NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_check (
  parent_id bigint NOT NULL REFERENCES exam_dv.link_check,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  checked_at timestamptz NOT NULL,
  score numeric(5,2) NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

CREATE TABLE exam_dv.sat_result (
  parent_id bigint NOT NULL REFERENCES exam_dv.link_preparation,
  load_dts timestamptz NOT NULL,
  record_source text NOT NULL,
  actual_grade smallint NOT NULL,
  recorded_at timestamptz NOT NULL,
  PRIMARY KEY(parent_id, load_dts)
);

-- Искусственные данные для демонстрации, не фактический результат студента.
INSERT INTO exam_3nf.student VALUES(1,'ST001','Денис Кулманаков');
INSERT INTO exam_3nf.discipline VALUES(1,'DB','Системы управления базами данных');
INSERT INTO exam_3nf.topic VALUES(1,'DB-T1',1,'Нормализация'),(2,'DB-T2',1,'Data Vault');
INSERT INTO exam_3nf.material VALUES(1,'M001','Конспект курса','https://example.org/notes');
INSERT INTO exam_3nf.topic_material VALUES(1,1),(2,1);
INSERT INTO exam_3nf.exam VALUES(1,'EX001',1,'2026-10-20');
INSERT INTO exam_3nf.preparation VALUES(1,1,1,'2026-10-01',5);
INSERT INTO exam_3nf.study_session VALUES
 (1,'S001',1,1,'2026-10-05 16:00+03','2026-10-05 17:00+03',60,'done'),
 (2,'S002',1,2,'2026-10-08 16:00+03',NULL,90,'planned');
INSERT INTO exam_3nf.self_check VALUES(1,'C001',1,1,'2026-10-05 17:10+03',80);
INSERT INTO exam_3nf.exam_result VALUES(1,5,'2026-10-20 15:00+03');


-- Загрузка полных снимков. Новые версии добавляются, старые не обновляются.
CREATE FUNCTION exam_dv.load_snapshot(p_load timestamptz) RETURNS void LANGUAGE plpgsql AS $$
BEGIN
INSERT INTO exam_dv.hub_student(business_key,load_dts,record_source) SELECT student_code,p_load,'exam_3nf' FROM exam_3nf.student ON CONFLICT(business_key) DO NOTHING;
INSERT INTO exam_dv.hub_discipline(business_key,load_dts,record_source) SELECT discipline_code,p_load,'exam_3nf' FROM exam_3nf.discipline ON CONFLICT(business_key) DO NOTHING;
INSERT INTO exam_dv.hub_topic(business_key,load_dts,record_source) SELECT topic_code,p_load,'exam_3nf' FROM exam_3nf.topic ON CONFLICT(business_key) DO NOTHING;
INSERT INTO exam_dv.hub_material(business_key,load_dts,record_source) SELECT material_code,p_load,'exam_3nf' FROM exam_3nf.material ON CONFLICT(business_key) DO NOTHING;
INSERT INTO exam_dv.hub_exam(business_key,load_dts,record_source) SELECT exam_code,p_load,'exam_3nf' FROM exam_3nf.exam ON CONFLICT(business_key) DO NOTHING;
INSERT INTO exam_dv.link_topic_discipline(topic_id,discipline_id,load_dts,record_source) SELECT ht.id,hd.id,p_load,'exam_3nf' FROM exam_3nf.topic t JOIN exam_3nf.discipline d USING(discipline_id) JOIN exam_dv.hub_topic ht ON ht.business_key=t.topic_code JOIN exam_dv.hub_discipline hd ON hd.business_key=d.discipline_code ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.link_topic_material(topic_id,material_id,load_dts,record_source) SELECT ht.id,hm.id,p_load,'exam_3nf' FROM exam_3nf.topic_material tm JOIN exam_3nf.topic t USING(topic_id) JOIN exam_3nf.material m USING(material_id) JOIN exam_dv.hub_topic ht ON ht.business_key=t.topic_code JOIN exam_dv.hub_material hm ON hm.business_key=m.material_code ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.link_exam_discipline(exam_id,discipline_id,load_dts,record_source) SELECT he.id,hd.id,p_load,'exam_3nf' FROM exam_3nf.exam e JOIN exam_3nf.discipline d USING(discipline_id) JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_dv.hub_discipline hd ON hd.business_key=d.discipline_code ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.link_preparation(student_id,exam_id,load_dts,record_source) SELECT hs.id,he.id,p_load,'exam_3nf' FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.link_session(student_id,exam_id,topic_id,event_code,load_dts,record_source) SELECT hs.id,he.id,ht.id,ss.session_code,p_load,'exam_3nf' FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_3nf.study_session ss USING(preparation_id) JOIN exam_3nf.topic t ON t.topic_id=ss.topic_id JOIN exam_dv.hub_topic ht ON ht.business_key=t.topic_code ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.link_check(student_id,exam_id,topic_id,event_code,load_dts,record_source) SELECT hs.id,he.id,ht.id,sc.check_code,p_load,'exam_3nf' FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_3nf.self_check sc USING(preparation_id) JOIN exam_3nf.topic t ON t.topic_id=sc.topic_id JOIN exam_dv.hub_topic ht ON ht.business_key=t.topic_code ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_student(parent_id,load_dts,record_source,full_name)
 SELECT par.id,p_load,'exam_3nf',src.full_name FROM exam_3nf.student src JOIN exam_dv.hub_student par ON par.business_key=src.student_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_student old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_student x WHERE x.parent_id=par.id) AND ROW(old.full_name) IS NOT DISTINCT FROM ROW(src.full_name)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_discipline(parent_id,load_dts,record_source,name)
 SELECT par.id,p_load,'exam_3nf',src.name FROM exam_3nf.discipline src JOIN exam_dv.hub_discipline par ON par.business_key=src.discipline_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_discipline old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_discipline x WHERE x.parent_id=par.id) AND ROW(old.name) IS NOT DISTINCT FROM ROW(src.name)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_topic(parent_id,load_dts,record_source,title)
 SELECT par.id,p_load,'exam_3nf',src.title FROM exam_3nf.topic src JOIN exam_dv.hub_topic par ON par.business_key=src.topic_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_topic old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_topic x WHERE x.parent_id=par.id) AND ROW(old.title) IS NOT DISTINCT FROM ROW(src.title)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_material(parent_id,load_dts,record_source,title,url)
 SELECT par.id,p_load,'exam_3nf',src.title,src.url FROM exam_3nf.material src JOIN exam_dv.hub_material par ON par.business_key=src.material_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_material old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_material x WHERE x.parent_id=par.id) AND ROW(old.title,old.url) IS NOT DISTINCT FROM ROW(src.title,src.url)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_exam(parent_id,load_dts,record_source,exam_date)
 SELECT par.id,p_load,'exam_3nf',src.exam_date FROM exam_3nf.exam src JOIN exam_dv.hub_exam par ON par.business_key=src.exam_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_exam old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_exam x WHERE x.parent_id=par.id) AND ROW(old.exam_date) IS NOT DISTINCT FROM ROW(src.exam_date)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_preparation(parent_id,load_dts,record_source,start_date,target_grade)
 SELECT par.id,p_load,'exam_3nf',p.start_date,p.target_grade FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_dv.link_preparation par ON par.student_id=hs.id AND par.exam_id=he.id
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_preparation old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_preparation x WHERE x.parent_id=par.id) AND ROW(old.start_date,old.target_grade) IS NOT DISTINCT FROM ROW(p.start_date,p.target_grade)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_session(parent_id,load_dts,record_source,planned_at,completed_at,duration_minutes,status)
 SELECT par.id,p_load,'exam_3nf',ss.planned_at,ss.completed_at,ss.duration_minutes,ss.status FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_3nf.study_session ss USING(preparation_id) JOIN exam_3nf.topic t ON t.topic_id=ss.topic_id JOIN exam_dv.hub_topic ht ON ht.business_key=t.topic_code JOIN exam_dv.link_session par ON par.event_code=ss.session_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_session old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_session x WHERE x.parent_id=par.id) AND ROW(old.planned_at,old.completed_at,old.duration_minutes,old.status) IS NOT DISTINCT FROM ROW(ss.planned_at,ss.completed_at,ss.duration_minutes,ss.status)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_check(parent_id,load_dts,record_source,checked_at,score)
 SELECT par.id,p_load,'exam_3nf',sc.checked_at,sc.score FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_3nf.self_check sc USING(preparation_id) JOIN exam_3nf.topic t ON t.topic_id=sc.topic_id JOIN exam_dv.hub_topic ht ON ht.business_key=t.topic_code JOIN exam_dv.link_check par ON par.event_code=sc.check_code
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_check old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_check x WHERE x.parent_id=par.id) AND ROW(old.checked_at,old.score) IS NOT DISTINCT FROM ROW(sc.checked_at,sc.score)) ON CONFLICT DO NOTHING;
INSERT INTO exam_dv.sat_result(parent_id,load_dts,record_source,actual_grade,recorded_at)
 SELECT par.id,p_load,'exam_3nf',r.actual_grade,r.recorded_at FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id) JOIN exam_3nf.exam e USING(exam_id) JOIN exam_dv.hub_student hs ON hs.business_key=s.student_code JOIN exam_dv.hub_exam he ON he.business_key=e.exam_code JOIN exam_3nf.exam_result r USING(preparation_id) JOIN exam_dv.link_preparation par ON par.student_id=hs.id AND par.exam_id=he.id
 WHERE NOT EXISTS (SELECT 1 FROM exam_dv.sat_result old WHERE old.parent_id=par.id AND old.load_dts=(SELECT max(x.load_dts) FROM exam_dv.sat_result x WHERE x.parent_id=par.id) AND ROW(old.actual_grade,old.recorded_at) IS NOT DISTINCT FROM ROW(r.actual_grade,r.recorded_at)) ON CONFLICT DO NOTHING;
END; $$;

SELECT exam_dv.load_snapshot('2026-10-21 10:00+03');
UPDATE exam_3nf.self_check SET score=95 WHERE check_id=1;
SELECT exam_dv.load_snapshot('2026-10-21 11:00+03');
-- Повтор того же снимка не добавляет версии.
SELECT exam_dv.load_snapshot('2026-10-21 11:00+03');

-- Проверка истории: ожидаются 80 и 95, всего две версии.
SELECT l.event_code,s.score,s.load_dts FROM exam_dv.sat_check s
 JOIN exam_dv.link_check l ON l.id=s.parent_id ORDER BY s.load_dts;
-- Текущие значения спутника.
SELECT DISTINCT ON(parent_id) parent_id,score,load_dts
 FROM exam_dv.sat_check ORDER BY parent_id,load_dts DESC;
-- План подготовки и достижение цели.
SELECT s.full_name,e.exam_code,p.target_grade,r.actual_grade,
 r.actual_grade=p.target_grade AS goal_reached
 FROM exam_3nf.preparation p JOIN exam_3nf.student s USING(student_id)
 JOIN exam_3nf.exam e USING(exam_id)
 LEFT JOIN exam_3nf.exam_result r USING(preparation_id);
COMMIT;
