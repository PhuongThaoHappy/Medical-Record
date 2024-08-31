--1) Phân cấp người dùng
-- Tạo các vai trò
CREATE ROLE patient_role;
CREATE ROLE doctor_role;
CREATE ROLE admin_role;
 
-- Tạo các người dùng và gán vai trò
CREATE ROLE patient_1 LOGIN PASSWORD '00000000';
GRANT patient_role TO patient_1;
 
CREATE ROLE doctor_1 LOGIN PASSWORD '00007737';
GRANT doctor_role TO doctor_1;
 
CREATE ROLE admin_1 LOGIN PASSWORD '11110000';
GRANT admin_role TO admin_1;
 
-- Gán quyền cho vai trò
-- Bệnh nhân chỉ có quyền SELECT
GRANT SELECT ON Medical_Record TO patient_role;
 
-- Bác sĩ có quyền SELECT, INSERT
GRANT SELECT, INSERT ON Medical_Record TO doctor_role;
 
-- Quản trị hệ thống có quyền SELECT, INSERT, UPDATE, DELETE
GRANT ALL ON Medical_Record TO admin_role;

--2) Lấy danh sách id của các bác sĩ có số bệnh nhân họ đã khám từ 7 bệnh nhân trở lên => Tính kpi bonus cuối tháng 
SELECT 
	med.dr_id, 
	dr.dr_name,
	COUNT(med.*) AS Num_of_patients
FROM 
medical_record med
NATURAL JOIN 
doctor dr
GROUP BY 
med.dr_id, 
dr.dr_name
HAVING 
COUNT(med.*) >= 7
ORDER BY 
Num_of_patients DESC;

--Tối ưu hóa: 
CREATE INDEX index1 ON medical_record(dr_id);

--3) Biết rằng độ tuổi nghỉ hưu của các bác sĩ được quy định như sau: 61 tuổi đối với nam, 56 tuổi đối với nữ. Hãy in ra thông tin các bác sĩ đã đến tuổi nghỉ hưu.
SELECT 
*
FROM 
doctor dr
WHERE
	(gender = 'Male'
	AND
	DATE_PART('year', AGE(current_date, dob)) >= 61)
	OR
	(gender = 'Female'
	AND
	DATE_PART('year', AGE(current_date, dob)) >= 56)

--Tối ưu hóa 
SELECT 
*
FROM 
doctor dr
WHERE 
gender = 'Male'
AND 
EXTRACT(year FROM AGE(current_date, dob)) >= 61
UNION
SELECT 
*
FROM 
doctor dr
WHERE 
gender = 'Female' AND EXTRACT(year FROM AGE(current_date, dob)) >= 56;

CREATE INDEX index2 ON doctor(gender,dob)

--4) Truy vấn để lấy danh sách bác sĩ và số bệnh nhân mà họ đã điều trị
SELECT 
d.dr_id, 
	d.dr_name,
	COUNT(med.medical_record_id) As PatientCount
FROM 
doctor d
JOIN 
medical_record med ON d.dr_id = med.dr_id
GROUP BY 
d.dr_id, 
d.dr_name
ORDER BY 
PatientCount DESC;

Tối ưu hóa: CREATE INDEX index1 ON medical_record(dr_id)

--5) Truy vấn để lấy danh sách thuốc và số lượng thuốc đã được kê đơn cho mỗi bệnh nhân
SELECT
	pre.medical_record_id,
p.identifier, 
	p.name, 
	m.medicine_name,
	SUM(pre.doses) AS TotalDoses
FROM
	medicine m
JOIN 
	prescription pre ON m.medicine_id = pre.medicine_id
JOIN 
	medical_record med ON med.medical_record_id = pre.medical_record_id
JOIN 
	personal_infor p On p.identifier = med.identifier
GROUP BY 
	m.medicine_name, 
	p.identifier, 
	pre.medical_record_id
ORDER BY 
	medical_record_id DESC;

--Tối ưu hóa: 
CREATE INDEX index3 ON prescription(medical_record_id)

--6) Truy vấn ra thông tin bệnh nhân và số lần nhập viện 
SELECT 
p.*, 
COUNT(med.identifier) AS AdmissionNums
FROM 
personal_infor p
JOIN 
medical_record med ON p.identifier = med.identifier
GROUP BY 
med.identifier,
p.identifier
ORDER BY 
AdmissionNums DESC;

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--7) Đối với các ca phẫu thuật có tình trạng nguy kịch và cần phải phẫu thuật gấp, viết truy vấn để đếm số lượng các ca phẫu thuật đó và đã có kết quả tốt vào cuối tuần => Tăng lương cho bác sĩ chịu trách nhiệm ca phẫu thuật đó.
SELECT 
COUNT(surgery_line_id) AS Surgery_Weekend_Success
FROM 
surgery_line 
WHERE 
results = 'Complete Success' AND EXTRACT(DOW FROM DATE) IN (6,0);
-- 6:Sat / 0:Sun

--Tối ưu hóa:
SELECT 
	COUNT(surgery_line_id) AS Surgery_Weekend_Success
FROM 
surgery_line 
WHERE 
results LIKE 'C%' AND EXTRACT(DOW FROM DATE) IN (6,0);
-- 6:Sat / 0:Sun
CREATE INDEX index5 ON Surgery_line(Results)

--8) Truy vấn để hiển thị thông tin các bác sĩ (còn đang công tác) ở các khoa 
SELECT 
dr.dr_id,
dr.dr_name,
dr.dr_position,
d.department_name,
dr.gender,
DATE_PART('year', AGE(current_date, dr.dob)) AS Age
FROM 
doctor dr
JOIN 
    	department d ON dr.department_id = d.department_id
WHERE
(dr.gender = 'Male' AND DATE_PART('year', AGE(current_date, dr.dob)) <= 61)
OR
(dr.gender = 'Female' AND DATE_PART('year', AGE(current_date, dr.dob)) <= 54)
ORDER BY 
department_name, 
dr_id

--Tối ưu hóa:
(SELECT 
dr.dr_id,
dr.dr_name,
dr.dr_position,
d.department_name,
dr.gender,
DATE_PART('year', AGE(current_date, dr.dob)) AS Age
FROM 
doctor dr
JOIN 
    	department d ON dr.department_id = d.department_id
WHERE
dr.gender LIKE 'M%' AND DATE_PART('year', AGE(current_date, dr.dob)) <= 61
)
UNION
(SELECT 
    dr.dr_id,
    dr.dr_name,
    dr.dr_position,
    d.department_name,
    dr.gender,
    DATE_PART('year', AGE(current_date, dr.dob)) AS Age
FROM 
    	doctor dr
JOIN 
    	department d ON dr.department_id = d.department_id
WHERE
    	dr.gender LIKE 'F%' AND DATE_PART('year', AGE(current_date, dr.dob)) <= 54
)
ORDER BY department_name, dr_id;
CREATE INDEX index6 ON doctor(gender,dob,department_id)

--9) Đối với các ca phẫu thuật cho trẻ sơ sinh (dưới 28 ngày tuổi) điều quan trọng nhất là cần phải có một số loại xét nghiệm nhất định để kiểm tra tình trạng của trẻ điển hình là xét nghiệm máu. Viết truy vấn đưa ra thông tin của trẻ sơ sinh đã được xét nghiệm máu (Blood tests)
SELECT 
p.* 
FROM 
personal_infor p
JOIN 
medical_record med ON p.identifier = med.identifier
JOIN 
test_line tl ON med.medical_record_id = tl.medical_record_id
JOIN 
test t ON tl.test_id = t.test_id
WHERE 
t.test_name = 'Blood tests' AND AGE(tl.date,p.dob) <= INTERVAL '28 days'
GROUP BY p.identifier

--Tối ưu hóa:
SELECT
	p.*
FROM 
personal_infor p
JOIN 
medical_record med ON p.identifier = med.identifier
JOIN 
test_line tl ON med.medical_record_id = tl.medical_record_id
JOIN 
test t ON tl.test_id = t.test_id
WHERE 
	test_name LIKE 'Bl%' AND AGE(p.dob) <= INTERVAL '28 days'

CREATE INDEX index7 ON personal_infor(dob)
CREATE INDEX index8 ON test(test_name)

--10) Hiển thị phần trăm của kết quả khám chữa bệnh ở bệnh viện -> Đánh giá tổng quan chất lượng khám, chữa bệnh ở bệnh viện -> Nâng cao chất lượng
SELECT 
    	results, 
COUNT(results),
    	TO_CHAR(COUNT(results) * 100.0 / (SELECT COUNT(*) FROM medical_record), 'FM999990.00') || '%' AS percentage
FROM 
    	medical_record
GROUP BY 
    	results;

--Tối ưu hóa: 
CREATE INDEX percentage ON medical_record(results)

--Function
--1) Tìm loại bệnh => Tra cứu lịch sử, phác đồ điều trị của một số căn bệnh => Phục vụ học tập, nghiên cứu.
CREATE FUNCTION find_by_disease(value character varying) 
RETURNS TABLE(
mid character varying, 
patient_name character varying,
admission date, 
discharge date, 
diagnosis character varying, 
results character varying
) AS $$
BEGIN
    	RETURN QUERY
    	SELECT 
        		med.medical_record_id,
p.name,
med.admission,
        		med.discharge,
        		med.diagnosis,
        		med.results
    	FROM 
        		personal_infor p
    	NATURAL JOIN 
       		medical_record med
    	WHERE 
        		med.diagnosis = value;
END;
$$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index9 ON medical_record(diagnosis)

--2) Tra cứu bệnh án dựa vào mã định danh của bệnh nhân => Tra cứu lịch sử thăm khám
CREATE FUNCTION find_by_id(value character varying) 
RETURNS TABLE(
mid character varying, 
patient_name character varying, 
admission date, 
discharge date, 
diagnosis character varying, 
results character varying
) AS $$
BEGIN
RETURN QUERY
SELECT 
	med.medical_record_id,
	p.name,
	med.admission,
	med.discharge,
	med.diagnosis,
	med.results
FROM
	personal_infor p
JOIN 
	medical_record med ON p.identifier = med.identifier
WHERE 
	med.identifier = value;
END;
$$ LANGUAGE plpgsql

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--3) Hiện nay số lượng các ca phẫu thuật do tai nạn giao thông đã tăng lên, hãy viết hàm để khi bệnh nhân làm phẫu thuật với mức giá loại phẫu thuật trên 35$ thì được giảm 15% loại phẫu thuật đó rồi tính tổng chi phí các loại phẫu thuật của bệnh nhân
CREATE OR REPLACE FUNCTION discounted_surgery_cost(value VARCHAR(25))
RETURNS NUMERIC AS $$
DECLARE
total_cost NUMERIC := 0;
surgery_cost NUMERIC;
discounted_cost NUMERIC;
BEGIN
FOR surgery_cost IN
SELECT 
s.price
FROM 
surgery s
JOIN 
surgery_line sl ON s.surgery_id = sl.surgery_id
JOIN 
medical_record med ON sl.medical_record_id = med.medical_record_id
JOIN 
personal_infor p ON med.identifier = p.identifier
WHERE 
p.identifier = value
LOOP
IF surgery_cost > 35 
THEN discounted_cost := surgery_cost * 0.85;
ELSE
discounted_cost := surgery_cost;
END IF;
total_cost := total_cost + discounted_cost;
END LOOP;
RETURN total_cost;
END;
$$ LANGUAGE plpgsql;
SELECT discounted_surgery_cost('851-17-6955');

--Tối ưu hóa: 
CREATE INDEX index10 ON surgery(price)
CREATE INDEX index4 ON medical_record(identifier)

--4) Viết hàm nhận đầu vào là identifier của bệnh nhân và trả về các loại xét nghiệm đã thực hiện:
CREATE OR REPLACE FUNCTION Patients_Tested(value varchar(255))
RETURNS TABLE(
	test_line_id VARCHAR,
	test_id VARCHAR,
	test_name VARCHAR,
	date DATE,
	results VARCHAR
) AS $$
BEGIN
	RETURN QUERY
	SELECT 
tl.test_line_id, 
tl.test_id, 
t.test_name, 
tl.date, 
tl.results
	FROM 
test_line tl
	NATURAL JOIN 
test t 
    	JOIN 
medical_record med ON tl.medical_record_id = med.medical_record_id 
	WHERE 
med.identifier = value;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM Patients_Tested('785-64-6151')
(Có bệnh nhân xét nghiệm và cả bệnh nhân không xét nghiệm gì)

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--5) Viết hàm nhận đầu vào là identifier của bệnh nhân và trả về các loại phẫu thuật đã thực hiện:
CREATE OR REPLACE FUNCTION patients_surgeries(value VARCHAR(255))
RETURNS TABLE(
surgery_line_id VARCHAR,
surgery_id VARCHAR,
surgery_name VARCHAR,
date DATE,
results VARCHAR
) AS $$
BEGIN
RETURN QUERY
SELECT 
sl.surgery_line_id, 
sl.surgery_id, 
s.surgery_name, 
sl.date, sl.results
    	FROM 
surgery_line sl
    	NATURAL JOIN 
surgery s 
    	JOIN 
medical_record med ON sl.medical_record_id = med.medical_record_id 
    	WHERE 
med.identifier = value;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM patients_surgeries('785-64-6151');

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--5) Hiển thị các loại thuốc mà bệnh nhân này đã sử dụng trong quá trình điều trị ở bệnh viện
--=> Hỗ trợ điều trị, tùy thuộc vào các loại thuốc đã từng sử dụng để xây dựng phác đồ điều trị hợp lí, tránh xung đột
 CREATE OR REPLACE FUNCTION medicine_usage_history(id VARCHAR(20))
 RETURNS TABLE(
   Medicine_name VARCHAR(500)
 )
 AS $$
 BEGIN
   	RETURN QUERY
   	SELECT 
m.medicine_name
FROM 
medicine m
JOIN 
prescription pre ON m.medicine_id = pre.medicine_id
JOIN 
medical_record med ON med.medical_record_id = pre.medical_record_id
WHERE med.identifier = id;
END;
$$ LANGUAGE plpgsql;
SELECT * FROM medicine_usage_history('420-42-9114')
--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--6) Tính giá trị hóa đơn xét nghiệm
CREATE OR REPLACE FUNCTION test_bill(id VARCHAR(20))
RETURNS TABLE(
	Name VARCHAR(50),
	Medical_record_id VARCHAR(20),
	Total MONEY
) AS $$
BEGIN
	RETURN QUERY
    	SELECT 
p.name, 
med.medical_record_id, 
SUM(bt.total) AS total
    	FROM 
bill_test bt
    	JOIN 
test_line tl ON tl.test_line_id = bt.test_line_id
    	JOIN 
medical_record med ON med.medical_record_id = tl.medical_record_id
    	JOIN 
personal_infor p ON p.identifier = med.identifier
    	WHERE 
med.identifier = id
    	GROUP BY 
p.name, 
med.medical_record_id, 
med.identifier
    	ORDER BY 
med.medical_record_id;
END;
$$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--7) Tính giá trị hóa đơn phẫu thuật
CREATE OR REPLACE FUNCTION surgery_bill(id VARCHAR(20))
RETURNS TABLE(
 	Name VARCHAR(50),
 	Medical_record_id VARCHAR(20),
 	Total MONEY
 ) AS $$
 BEGIN
 	RETURN QUERY
     	SELECT 
p.name, 
med.medical_record_id, 
SUM(bs.total) AS total
FROM 
bill_surgery bs
JOIN 
surgery_line sl ON sl.surgery_line_id = bs.surgery_line_id
JOIN 
medical_record med ON med.medical_record_id = sl.medical_record_id
JOIN 
personal_infor p ON p.identifier = med.identifier
WHERE 
med.identifier = id
GROUP BY 
p.name, 
med.medical_record_id, 
med.identifier
ORDER BY med.medical_record_id;
END;
$$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--8) Tính giá trị hóa đơn đơn thuốc
CREATE OR REPLACE FUNCTION prescription_bill(id VARCHAR(20))
RETURNS TABLE(
 	Name VARCHAR(50),
 	Medical_record_id VARCHAR(20),
 	Total MONEY
 ) AS $$
 BEGIN
 	RETURN QUERY
     	SELECT
p.name,
med.medical_record_id, 
SUM(bp.total) AS total
FROM 
bill_prescription bp
JOIN 
prescription pre ON pre.prescription_id = bp.prescription_id
JOIN 
medical_record med ON med.medical_record_id = pre.medical_record_id
JOIN 
personal_infor p ON p.identifier = med.identifier
WHERE 
med.identifier = id
GROUP BY 
p.name, 
med.medical_record_id, 
med.identifier
ORDER BY 
med.medical_record_id;
END;
$$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)

--9) viết hàm để tính tổng chi phí dịch vụ của mỗi bệnh nhân khi khám bệnh (bao gồm đơn thuốc, xét nghiệm và phẫu thuật nếu có)
CREATE OR REPLACE FUNCTION bill(id VARCHAR(20), type_of_bill TEXT)
RETURNS TABLE(
 	Name VARCHAR(50),
 	Medical_record_id VARCHAR(20),
 	Total MONEY
 ) AS $$
 BEGIN
 	IF type_of_bill = 'test'
 	THEN RETURN QUERY
     	SELECT 
tb.name, 
tb.medical_record_id, 
tb.total
FROM 
test_bill(id) AS tb;

ELSIF type_of_bill = 'surgery' 
THEN RETURN QUERY
SELECT 
sb.name, 
sb.medical_record_id, 
sb.total
FROM 
surgery_bill(id) AS sb;

ELSIF type_of_bill = 'prescription'
THEN RETURN QUERY
SELECT 
pb.name, 
pb.medical_record_id, 
pb.total
FROM 
prescription_bill(id) AS pb;

ELSIF type_of_bill = 'all'
THEN RETURN QUERY
SELECT 
combined.name, 
combined.medical_record_id, 
SUM(combined.total) AS total
FROM (
         	SELECT 
tb.name, 
tb.medical_record_id, 
tb.total
FROM 
test_bill(id) AS tb


UNION ALL


SELECT 
sb.name, 
sb.medical_record_id, 
sb.total
FROM 
surgery_bill(id) AS sb


UNION ALL


SELECT 
pb.name, 
pb.medical_record_id, 
pb.total
FROM 
prescription_bill(id) AS pb) AS combined
GROUP BY 
combined.name, 
combined.medical_record_id
ORDER BY combined.medical_record_id;
	
ELSE
     	RAISE EXCEPTION 'Invalid type_of_bill value. Allowed values are: test, surgery, prescription, all';
 	END IF;
 END;
 $$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index4 ON medical_record(identifier)
CREATE INDEX index11 ON surgery_line(medical_record_id)
CREATE INDEX index12 ON test_line(medical_record_id)
CREATE INDEX index13 ON prescription_line(medical_record_id)

--10) Hiển thị bệnh án gần đây nhất của bệnh nhân
CREATE OR REPLACE FUNCTION find_recently_med(value VARCHAR(15))
RETURNS TABLE(
	Patient_name VARCHAR(35),
	Medical_record_id VARCHAR(20),
	Doctor_name VARCHAR(20),
	Admission DATE,
	Discharge DATE,
	Diagnosis VARCHAR(500),
	Result VARCHAR(255)
 ) AS $$
BEGIN
	RETURN QUERY
	SELECT
		p.name,
		med.medical_record_id,
		dr.dr_name,
		med.admission,
		med.discharge,
		med.diagnosis,
		med.results
	FROM 
medical_record med
NATURAL JOIN 
personal_infor p
JOIN 
doctor dr ON dr.dr_id = med.dr_id
WHERE 
med.identifier = value
ORDER BY 
med.admission DESC
LIMIT 1;
END;  
$$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index12 ON medical_record(identifier,admission)

--11) Hiển thị các bệnh nhân được điều trị bởi 1 bác sĩ cụ thể
CREATE OR REPLACE FUNCTION get_patients_by_doctor(value VARCHAR(25))
RETURNS TABLE(
identifier VARCHAR(25),
name VARCHAR(100),
dob DATE,
gender VARCHAR(50),
phone VARCHAR(15),
address VARCHAR(255)
) AS $$
BEGIN
RETURN QUERY
SELECT 
p.identifier, 
p.name, 
p.dob, 
p.gender, 
p.phone, 
p.address
FROM 
personal_infor p
JOIN 
medical_record med ON p.identifier = med.identifier
WHERE 
med.doctor_id = value;
END;
$$ LANGUAGE plpgsql;

--12) Biến đầu vào là 1 khoảng thời gian => Đưa ra tổng số xét nghiệm, phẫu thuật của từng khoa đã thực hiện => Xem xét nâng cấp các khoa đó (csvc, tuyển thêm bác sĩ)
CREATE OR REPLACE FUNCTION upgrade_department(from_year INTEGER, to_year INTEGER)
RETURNS TABLE(
department_name VARCHAR(255),
quantity INTEGER
) AS $$
DECLARE 
total INTEGER;
cnt_test INTEGER := 0;
cnt_surgery INTEGER := 0;
k RECORD;
fromdate DATE;
todate DATE;
BEGIN
fromdate := to_date(from_year::text, 'YYYY');
todate := to_date(to_year::text, 'YYYY');

FOR k IN
SELECT 
d.department_id, 
d.department_name
FROM 
department d
LOOP
SELECT 
COUNT(*) INTO cnt_test
        		FROM 
test t
        		JOIN 
test_line tl ON t.test_id = tl.test_id
        		WHERE 
t.department_id = k.department_id
        			AND 
tl.date BETWEEN fromdate AND todate;
        		SELECT 
COUNT(*) INTO cnt_surgery
        			FROM 
surgery s
JOIN 
surgery_line sl ON s.surgery_id = sl.surgery_id
WHERE 
s.department_id = k.department_id
AND 
sl.date BETWEEN fromdate AND todate;
        			total := cnt_test + cnt_surgery;
        	IF total > 0 THEN
            	department_name := k.department_name;
            	quantity := total;
RETURN NEXT;
END IF;
    	END LOOP;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM upgrade_department(2020, 2023)
ORDER BY quantity DESC;

--Tối ưu hóa: 
CREATE INDEX index13 ON test(department_id)
CREATE INDEX index14 ON surgery(department_id)

--13) Hiển thị ra các dạng thuốc của một loại thuốc => tùy thuộc vào thể trạng của bệnh nhân để sử dụng các dạng thuốc khác nhau.
CREATE OR REPLACE FUNCTION form(value VARCHAR(500))
RETURNS TABLE(
	dosage_form VARCHAR(35)
)
AS $$
BEGIN
	RETURN QUERY
	SELECT 
m.dosage_form
	FROM 
medicine m
	WHERE 
m.medicine_name = value;
END;
$$ LANGUAGE plpgsql;

--Tối ưu hóa: 
CREATE INDEX index15 ON medicine(medicine_name)


--Trigger
--1) Viết trigger cho việc khi cập nhật số lượng bác sĩ thì thông báo ra hay không lượng bác sĩ cần phải tuyển thêm khi số lượng bác sĩ nghỉ hưu trên 200 người
CREATE OR REPLACE FUNCTION check_retired_doctors()
RETURNS TRIGGER AS $$
DECLARE 
retired_doc_count int;
BEGIN
	SELECT COUNT(*) INTO retired_doc_count
	FROM doctor
	WHERE 
(gender = 'Male' AND DATE_PART('year', AGE(current_date, dob)) >= 61)
		OR
		(gender = 'Female' AND DATE_PART('year', AGE(current_date, dob)) >= 56);
	IF retired_doc_count > 200 THEN
		RAISE NOTICE 'Number of retired doctors is %: Need to hire more doctors!',retired_doc_count;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;
CREATE OR REPLACE TRIGGER Notice_doc
AFTER INSERT OR DELETE OR UPDATE ON doctor
FOR EACH ROW
EXECUTE FUNCTION check_retired_doctors()

INSERT INTO doctor(dr_id,dr_name,dr_position,department_id,dob,gender,phone)
VALUES('Dr-000-000-001','Hinh','nurse','K490','2004-05-08','Male','0921345678')
DELETE FROM doctor WHERE dr_name = 'Hinh'

--2) trigger để kiểm tra khi số lượng bệnh án đang trong quá trình hoặc liên quan đến vấn đề về việc điều trị quá 1000 thì dừng việc tiếp nhận thêm bệnh án
CREATE OR REPLACE FUNCTION check_medical_record_count ()
RETURNS TRIGGER AS $$
BEGIN
	IF(
SELECT 
COUNT(*) FROM medical_record
	   	WHERE 
medical_record.results IN('Under treatment')) >= 1000
	THEN
		RAISE EXCEPTION 'The number of patients is overloaded, unable to accept more patients!';
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;
CREATE OR REPLACE TRIGGER Trigger_medical_record_count
BEFORE INSERT ON medical_record
FOR EACH ROW
EXECUTE FUNCTION check_medical_record_count();
 
INSERT INTO medical_record(medical_record_id,identifier,doctor_id,admission,discharge,diagnosis,results)
VALUES(N'MID-000-000-111',N'421-124-424',N'Dr-001-001-001','1979-02-12','1979-02-24',N'Flu',N'Relapse');
INSERT INTO personal_infor (identifier, name, dob, gender, phone, address)
VALUES (N'421-124-424', N'John Doe', '1980-01-01', N'Male', N'1234567890', N'123 Main St');

--3) Trigger để mỗi khi thêm một loại phẫu thuật mới liên quan về tim vào thì chi phí không được dưới 40 USD do những ca phẫu thuật tim đòi hỏi sự phức tạp
CREATE OR REPLACE FUNCTION check_Heart_money()
RETURNS TRIGGER AS $$
BEGIN
	IF NEW.surgery_name ILIKE '%heart%' THEN   
		IF NEW.price ::NUMERIC < 40 THEN
			RAISE EXCEPTION 'The cost for heart-related surgery should not be less than 40 USD';
		END IF;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;
CREATE OR REPLACE TRIGGER Heart_money
AFTER INSERT OR UPDATE ON surgery
FOR EACH ROW
EXECUTE FUNCTION check_Heart_money();

INSERT INTO surgery(surgery_id,surgery_name,department_id,price)
VALUES('S-131','heart valve replacement surgery','K448','20.00')


--4) Viết trigger để Update phần Total của Bill_Surgery (nếu thực hiện vào thứ 7, chủ nhật thì total = total * 1.5)
-- Tạo hàm để tính toán total
CREATE OR REPLACE FUNCTION calculate_total(p_surgery_id VARCHAR, p_surgery_date DATE)
RETURNS MONEY AS $$
DECLARE
    	surgery_price MONEY;
    	calculated_total MONEY;
BEGIN
-- Lấy giá trị Price từ bảng surgery
   	SELECT 
Price INTO surgery_price
    	FROM 
surgery
    	WHERE 
surgery.surgery_id = p_surgery_id;
    -- Tính toán total
    IF EXTRACT(DOW FROM p_surgery_date) IN (0, 6) THEN
        	-- Nếu là thứ Bảy (6) hoặc Chủ Nhật (0), nhân đôi giá trị
        	calculated_total := surgery_price * 1.5;
    ELSE
        	calculated_total := surgery_price;
    END IF;
    RETURN calculated_total;
END;
$$ LANGUAGE plpgsql;

-- Tạo trigger để cập nhật total trong bảng bill_surgery
CREATE OR REPLACE FUNCTION update_bill_total()
RETURNS TRIGGER AS $$
BEGIN
    -- Chèn giá trị total mới vào bảng bill_surgery
    INSERT INTO bill_surgery (bill_id, surgery_line_id, total)
    VALUES (NEW.surgery_line_id, NEW.surgery_line_id, 
            calculate_total(NEW.surgery_id, NEW.date));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Tạo trigger để gọi hàm update_bill_total sau khi thêm bản ghi vào bảng surgery_line
CREATE TRIGGER trg_update_bill_total
AFTER INSERT ON surgery_line
FOR EACH ROW
EXECUTE FUNCTION update_bill_total();

INSERT INTO Surgery_line(surgery_line_id,surgery_id,medical_record_id,referring,attending,date,results)
VALUES('SID-217-332-421','S-653', 'MID-197-052-573', 'Dr-196-183-121', 'Dr-197-811-029', '1973-09-22', 'Postoperative Complications');

INSERT INTO bill_surgery (bill_id, surgery_line_id, total)
VALUES ('B-219-321-313', 'SID-218-332-421',calculate_total('S-653','1973-09-22'));

--5) Viết trigger để Update phần Total của Bill_Test (nếu thực hiện vào thứ 7, chủ nhật thì total = total * 1.5)
Create Or Replace Function calculate_test_total(p_test_id varchar,p_test_date date)
Returns Money As $$
Declare
	test_price MONEY;
    calculated_total MONEY;
Begin
	Select price Into test_price 
	From test
	Where test.test_id = p_test_id;
	If Extract(Dow From p_test_date) In (0, 6) Then
        calculated_total := test_price * 1.5;
    Else
        calculated_total := test_price;
    End If;
    Return calculated_total;
End;
$$
language plpgsql;
Create Or Replace Function update_bill_test_total()
Returns Trigger As $$
Begin
	Insert Into bill_test(bill_id,test_line_id,total)
	Values(New.test_line_id,New.test_line_id,calculate_test_total(New.test_id,New.date));
	Return New;
End;
$$
language plpgsql;
Create Trigger trg_update_bill_test_total
After Insert On test_line
For Each Row
Execute Function update_bill_test_total();

Insert Into test_line(test_line_id,test_id,medical_record_id,referring,attending,date,results)
Values('TID-193-924-270','T-288','MID-194-660-900','Dr-197-830-441','Dr-198-586-631','2024-06-16','Average')

Update bill_test
Set bill_id = 'B-193-924-270'
Where test_line_id = 'TID-193-924-270'

--6) Viết trigger để Update phần Total của Bill_Prescription
CREATE OR REPLACE FUNCTION calculate_prescription_total(p_prescription_id VARCHAR, p_prescription_date DATE)
RETURNS MONEY AS $$
DECLARE
    medicine_price MONEY;
    calculated_total MONEY;
BEGIN 
    SELECT price INTO medicine_price
    FROM medicine
    WHERE medicine.medicine_id = p_prescription_id;
    IF EXTRACT(DOW FROM p_prescription_date) IN (0, 6) THEN
        -- Nếu là thứ Bảy (6) hoặc Chủ Nhật (0), nhân đôi giá trị
        calculated_total := medicine_price * 1.5;
    ELSE
        calculated_total := medicine_price;
    END IF;
    RETURN calculated_total;
END;
$$ LANGUAGE plpgsql;
CREATE OR REPLACE FUNCTION update_bill_prescription_total()
RETURNS TRIGGER AS $$
BEGIN
    -- Chèn giá trị total mới vào bảng bill_prescription
    INSERT INTO bill_prescription (bill_id, prescription_id, total)
    VALUES (NEW.prescription_id, NEW.prescription_id, 
            calculate_prescription_total(NEW.medicine_id, NEW.date));
 
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_update_bill_prescription_total
AFTER INSERT ON prescription
FOR EACH ROW
EXECUTE FUNCTION update_bill_prescription_total();

INSERT INTO prescription(prescription_id,medicine_id,date,medical_record_id,dr_id,dosage,doses)
VALUES('PID-210-310-410','M-309-662-568','2024-06-16','MID-206-304-413','Dr-200-487-897','After meals_two doses a day','10')

UPDATE bill_prescription
SET bill_id = 'B-210-310-410'
WHERE prescription_id = 'PID-210-310-410'

--7) Trigger để kiểm tra id của 1 loại thuốc thì có tồn tại ở trong đơn thuốc hay không 
CREATE OR REPLACE FUNCTION check_med_exists()
RETURNS TRIGGER AS $$
DECLARE 
	med_exists Boolean;
BEGIN
	--check if medicine_id exists in medicine
	SELECT EXISTS(
		SELECT 1 
FROM medicine
		WHERE medicine_id = NEW.medicine_id INTO med_exists;
	-- Raise exception if not exists
	IF NOT med_exists THEN
		RAISE EXCEPTION 'medicine_id Number % does not exists here', New.medicine_id;
	END IF;
	RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;
CREATE TRIGGER check_med_before_insert
BEFORE INSERT OR UPDATE ON medicine
FOR EACH ROW
EXECUTE FUNCTION check_med_exists();

UPDATE medicine
SET medicine_id = 'M-000-000-000'
WHERE medicine_name = 'Tolnaftate'


