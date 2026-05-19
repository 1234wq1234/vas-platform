
SET SERVEROUTPUT ON SIZE UNLIMITED;


INSERT INTO app_users (user_id, username, password_hash, display_name, role_name)
SELECT seq_app_user.NEXTVAL, 'admin', 'admin123', 'VAS Admin', 'ADMIN' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM app_users WHERE username = 'admin');

INSERT INTO app_users (user_id, username, password_hash, display_name, role_name)
SELECT seq_app_user.NEXTVAL, 'operator', 'operator123', 'VAS Operator', 'OPERATOR' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM app_users WHERE username = 'operator');

COMMIT;


INSERT INTO subscribers (subscriber_id, msisdn, full_name, balance, status)
SELECT seq_subscriber.NEXTVAL, '905551111001', 'Ahmet Yilmaz', 500.00, 'ACTIVE' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM subscribers WHERE msisdn = '905551111001');

INSERT INTO subscribers (subscriber_id, msisdn, full_name, balance, status)
SELECT seq_subscriber.NEXTVAL, '905551111002', 'Ayse Demir', 150.00, 'ACTIVE' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM subscribers WHERE msisdn = '905551111002');

INSERT INTO subscribers (subscriber_id, msisdn, full_name, balance, status)
SELECT seq_subscriber.NEXTVAL, '905551111003', 'Mehmet Kaya', 0.00, 'ACTIVE' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM subscribers WHERE msisdn = '905551111003');

INSERT INTO subscribers (subscriber_id, msisdn, full_name, balance, status)
SELECT seq_subscriber.NEXTVAL, '905551111004', 'Zeynep Celik', 80.00, 'INACTIVE' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM subscribers WHERE msisdn = '905551111004');

COMMIT;


INSERT INTO services (service_id, service_code, service_name, service_type, price, description)
SELECT seq_service.NEXTVAL, 'MUSIC_SUB', 'Aylik Muzik Paketi', 'SUBSCRIPTION', 29.90,
       'Sinirsiz muzik streaming' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM services WHERE service_code = 'MUSIC_SUB');

INSERT INTO services (service_id, service_code, service_name, service_type, price, description)
SELECT seq_service.NEXTVAL, 'GAME_SUB', 'Oyun Kulubu', 'SUBSCRIPTION', 19.90,
       'Premium oyun icerikleri' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM services WHERE service_code = 'GAME_SUB');

INSERT INTO services (service_id, service_code, service_name, service_type, price, description)
SELECT seq_service.NEXTVAL, 'RINGTONE_OT', 'Zil Sesi Paketi', 'ONE_TIME', 9.90,
       'Tek seferlik zil sesi indirme' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM services WHERE service_code = 'RINGTONE_OT');

INSERT INTO services (service_id, service_code, service_name, service_type, price, description)
SELECT seq_service.NEXTVAL, 'WALLPAPER_OT', 'Duvar Kagidi', 'ONE_TIME', 4.90,
       'HD duvar kagidi' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM services WHERE service_code = 'WALLPAPER_OT');

INSERT INTO services (service_id, service_code, service_name, service_type, price, description)
SELECT seq_service.NEXTVAL, 'NEWS_SUB', 'Haber Bulteni', 'SUBSCRIPTION', 14.90,
       'Gunluk haber ozeti' FROM dual
WHERE NOT EXISTS (SELECT 1 FROM services WHERE service_code = 'NEWS_SUB');

COMMIT;


DECLARE
    v_sub1_id    NUMBER;
    v_sub2_id    NUMBER;
    v_music_id   NUMBER;
    v_game_id    NUMBER;
    v_ring_id    NUMBER;
    v_wall_id    NUMBER;
    v_id         NUMBER;
    v_code       VARCHAR2(50);
    v_msg        VARCHAR2(1000);
    v_invalid    NUMBER;
BEGIN
    
    SELECT COUNT(*) INTO v_invalid
    FROM user_objects
    WHERE object_name = 'PKG_VAS_CORE'
      AND object_type = 'PACKAGE BODY'
      AND status = 'INVALID';

    IF v_invalid > 0 THEN
        RAISE_APPLICATION_ERROR(-20001,
            'PKG_VAS_CORE INVALID! Once 02_packages.sql dosyasini tekrar F5 ile calistirin.');
    END IF;

    SELECT subscriber_id INTO v_sub1_id FROM subscribers WHERE msisdn = '905551111001';
    SELECT subscriber_id INTO v_sub2_id FROM subscribers WHERE msisdn = '905551111002';
    SELECT service_id INTO v_music_id FROM services WHERE service_code = 'MUSIC_SUB';
    SELECT service_id INTO v_game_id FROM services WHERE service_code = 'GAME_SUB';
    SELECT service_id INTO v_ring_id FROM services WHERE service_code = 'RINGTONE_OT';
    SELECT service_id INTO v_wall_id FROM services WHERE service_code = 'WALLPAPER_OT';

    
    BEGIN
        pkg_vas_core.subscribe(v_sub1_id, v_music_id, 'seed', v_id, v_code, v_msg);
        DBMS_OUTPUT.PUT_LINE('Sub1: ' || v_code || ' - ' || v_msg);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Sub1 atlandi: ' || SQLERRM);
    END;

   
    pkg_vas_core.subscribe(v_sub1_id, v_music_id, 'seed', v_id, v_code, v_msg);
    DBMS_OUTPUT.PUT_LINE('Dup test: ' || v_code || ' - ' || v_msg);

  
    pkg_vas_core.purchase_one_time(v_sub1_id, v_ring_id, 'seed', v_id, v_code, v_msg);
    DBMS_OUTPUT.PUT_LINE('OT1: ' || v_code || ' - ' || v_msg);

    pkg_vas_core.purchase_one_time(v_sub1_id, v_ring_id, 'seed', v_id, v_code, v_msg);
    DBMS_OUTPUT.PUT_LINE('OT2 (repeat): ' || v_code || ' - ' || v_msg);

    
    BEGIN
        pkg_vas_core.subscribe(v_sub2_id, v_game_id, 'seed', v_id, v_code, v_msg);
        DBMS_OUTPUT.PUT_LINE('Sub2: ' || v_code || ' - ' || v_msg);
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Sub2 atlandi: ' || SQLERRM);
    END;

    pkg_vas_core.purchase_one_time(v_sub2_id, v_wall_id, 'seed', v_id, v_code, v_msg);
    DBMS_OUTPUT.PUT_LINE('OT sub2: ' || v_code || ' - ' || v_msg);

    COMMIT;
    DBMS_OUTPUT.PUT_LINE('=== Seed islemleri tamamlandi ===');
END;
/

COMMIT;
