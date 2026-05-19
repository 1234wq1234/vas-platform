
CREATE OR REPLACE PACKAGE pkg_vas_audit AS
    PROCEDURE log_action (
        p_action_code     IN VARCHAR2,
        p_action_category IN VARCHAR2,
        p_subscriber_id   IN NUMBER   DEFAULT NULL,
        p_service_id      IN NUMBER   DEFAULT NULL,
        p_reference_id    IN NUMBER   DEFAULT NULL,
        p_reference_type  IN VARCHAR2 DEFAULT NULL,
        p_performed_by    IN VARCHAR2 DEFAULT 'SYSTEM',
        p_status_result   IN VARCHAR2,
        p_message         IN VARCHAR2 DEFAULT NULL,
        p_detail_json     IN VARCHAR2 DEFAULT NULL,
        p_ip_address      IN VARCHAR2 DEFAULT NULL,
        p_result_code     IN VARCHAR2 DEFAULT NULL
    );
END pkg_vas_audit;
/

CREATE OR REPLACE PACKAGE BODY pkg_vas_audit AS
    PROCEDURE log_action (
        p_action_code     IN VARCHAR2,
        p_action_category IN VARCHAR2,
        p_subscriber_id   IN NUMBER   DEFAULT NULL,
        p_service_id      IN NUMBER   DEFAULT NULL,
        p_reference_id    IN NUMBER   DEFAULT NULL,
        p_reference_type  IN VARCHAR2 DEFAULT NULL,
        p_performed_by    IN VARCHAR2 DEFAULT 'SYSTEM',
        p_status_result   IN VARCHAR2,
        p_message         IN VARCHAR2 DEFAULT NULL,
        p_detail_json     IN VARCHAR2 DEFAULT NULL,
        p_ip_address      IN VARCHAR2 DEFAULT NULL,
        p_result_code     IN VARCHAR2 DEFAULT NULL
    ) IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        INSERT INTO audit_logs (
            log_id, action_code, action_category, subscriber_id, service_id,
            reference_id, reference_type, performed_by, status_result,
            message, detail_json, ip_address
        ) VALUES (
            seq_audit_log.NEXTVAL, p_action_code, p_action_category,
            p_subscriber_id, p_service_id, p_reference_id, p_reference_type,
            p_performed_by, p_status_result, p_message, p_detail_json, p_ip_address
        );
        COMMIT;
    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
    END log_action;
END pkg_vas_audit;
/


CREATE OR REPLACE PACKAGE pkg_vas_core AS
 
    PROCEDURE add_service (
        p_service_code  IN VARCHAR2,
        p_service_name  IN VARCHAR2,
        p_service_type  IN VARCHAR2,
        p_price         IN NUMBER,
        p_description   IN VARCHAR2 DEFAULT NULL,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_service_id    OUT NUMBER,
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    );

    PROCEDURE deactivate_service (
        p_service_id    IN NUMBER,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    );

    PROCEDURE topup_balance (
        p_subscriber_id IN NUMBER,
        p_amount        IN NUMBER,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    );

    PROCEDURE subscribe (
        p_subscriber_id     IN NUMBER,
        p_service_id        IN NUMBER,
        p_performed_by      IN VARCHAR2 DEFAULT 'SYSTEM',
        p_subscription_id   OUT NUMBER,
        p_result_code       OUT VARCHAR2,
        p_result_msg        OUT VARCHAR2
    );

    PROCEDURE cancel_subscription (
        p_subscription_id IN NUMBER,
        p_performed_by    IN VARCHAR2 DEFAULT 'SYSTEM',
        p_result_code     OUT VARCHAR2,
        p_result_msg      OUT VARCHAR2
    );

    PROCEDURE purchase_one_time (
        p_subscriber_id IN NUMBER,
        p_service_id    IN NUMBER,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_purchase_id   OUT NUMBER,
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    );

    PROCEDURE validate_login (
        p_username     IN VARCHAR2,
        p_password     IN VARCHAR2,
        p_user_id      OUT NUMBER,
        p_display_name OUT VARCHAR2,
        p_result_code  OUT VARCHAR2,
        p_result_msg   OUT VARCHAR2
    );
END pkg_vas_core;
/

CREATE OR REPLACE PACKAGE BODY pkg_vas_core AS

    c_ok              CONSTANT VARCHAR2(20) := 'OK';
    c_err_subscriber  CONSTANT VARCHAR2(30) := 'SUBSCRIBER_NOT_FOUND';
    c_err_sub_inact   CONSTANT VARCHAR2(30) := 'SUBSCRIBER_INACTIVE';
    c_err_service     CONSTANT VARCHAR2(30) := 'SERVICE_NOT_FOUND';
    c_err_svc_inact   CONSTANT VARCHAR2(30) := 'SERVICE_INACTIVE';
    c_err_wrong_type  CONSTANT VARCHAR2(30) := 'WRONG_SERVICE_TYPE';
    c_err_balance     CONSTANT VARCHAR2(30) := 'INSUFFICIENT_BALANCE';
    c_err_duplicate   CONSTANT VARCHAR2(30) := 'DUPLICATE_SUBSCRIPTION';
    c_err_not_active  CONSTANT VARCHAR2(30) := 'SUBSCRIPTION_NOT_ACTIVE';
    c_err_not_found   CONSTANT VARCHAR2(30) := 'SUBSCRIPTION_NOT_FOUND';
    c_err_login       CONSTANT VARCHAR2(30) := 'INVALID_CREDENTIALS';
    c_err_duplicate_code CONSTANT VARCHAR2(30) := 'SERVICE_CODE_EXISTS';
    c_err_system      CONSTANT VARCHAR2(30) := 'SYSTEM_ERROR';

    PROCEDURE add_service (
        p_service_code  IN VARCHAR2,
        p_service_name  IN VARCHAR2,
        p_service_type  IN VARCHAR2,
        p_price         IN NUMBER,
        p_description   IN VARCHAR2 DEFAULT NULL,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_service_id    OUT NUMBER,
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    ) IS
    BEGIN
        p_service_id  := NULL;
        p_result_code := c_err_system;
        p_result_msg  := 'Bilinmeyen hata';

        IF p_service_type NOT IN ('SUBSCRIPTION', 'ONE_TIME') THEN
            p_result_code := c_err_wrong_type;
            p_result_msg  := 'Servis tipi SUBSCRIPTION veya ONE_TIME olmali';
            pkg_vas_audit.log_action('ADD_SERVICE', 'SERVICE', NULL, NULL, NULL, NULL,
                p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        IF p_price <= 0 THEN
            p_result_code := c_err_system;
            p_result_msg  := 'Fiyat sifirdan buyuk olmali';
            pkg_vas_audit.log_action('ADD_SERVICE', 'SERVICE', NULL, NULL, NULL, NULL,
                p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        p_service_id := seq_service.NEXTVAL;
        INSERT INTO services (service_id, service_code, service_name, service_type, price, description)
        VALUES (p_service_id, UPPER(TRIM(p_service_code)), TRIM(p_service_name),
                UPPER(p_service_type), p_price, p_description);

        p_result_code := c_ok;
        p_result_msg  := 'Servis eklendi: ' || p_service_code;

        COMMIT;

        pkg_vas_audit.log_action('ADD_SERVICE', 'SERVICE', NULL, p_service_id, p_service_id, 'SERVICE',
            p_performed_by, 'SUCCESS', p_result_msg, NULL);

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            p_service_id  := NULL;
            p_result_code := c_err_duplicate_code;
            p_result_msg  := 'Bu servis kodu zaten mevcut: ' || p_service_code;
            pkg_vas_audit.log_action('ADD_SERVICE', 'SERVICE', NULL, NULL, NULL, NULL,
                p_performed_by, 'FAILURE', p_result_msg, NULL);
        WHEN OTHERS THEN
            ROLLBACK;
            p_result_code := c_err_system;
            p_result_msg  := SQLERRM;
            pkg_vas_audit.log_action('ADD_SERVICE', 'SERVICE', NULL, NULL, NULL, NULL,
                p_performed_by, 'FAILURE', p_result_msg, NULL);
    END add_service;

    PROCEDURE deactivate_service (
        p_service_id    IN NUMBER,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    ) IS
        v_cnt NUMBER;
    BEGIN
        UPDATE services SET status = 'INACTIVE', updated_at = SYSTIMESTAMP
        WHERE service_id = p_service_id AND status = 'ACTIVE';

        IF SQL%ROWCOUNT = 0 THEN
            SELECT COUNT(*) INTO v_cnt FROM services WHERE service_id = p_service_id;
            IF v_cnt = 0 THEN
                p_result_code := c_err_service;
                p_result_msg  := 'Servis bulunamadi: ' || p_service_id;
            ELSE
                p_result_code := c_err_svc_inact;
                p_result_msg  := 'Servis zaten pasif: ' || p_service_id;
            END IF;
            pkg_vas_audit.log_action('DEACTIVATE_SERVICE', 'SERVICE', NULL, p_service_id,
                p_service_id, 'SERVICE', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        COMMIT;

        p_result_code := c_ok;
        p_result_msg  := 'Servis pasife alindi: ' || p_service_id;
        pkg_vas_audit.log_action('DEACTIVATE_SERVICE', 'SERVICE', NULL, p_service_id,
            p_service_id, 'SERVICE', p_performed_by, 'SUCCESS', p_result_msg, NULL);
    END deactivate_service;

    PROCEDURE topup_balance (
        p_subscriber_id IN NUMBER,
        p_amount        IN NUMBER,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    ) IS
        v_status subscribers.status%TYPE;
        v_balance subscribers.balance%TYPE;
    BEGIN
        IF p_amount <= 0 THEN
            p_result_code := c_err_system;
            p_result_msg  := 'Yukleme tutari pozitif olmali';
            RETURN;
        END IF;

        SELECT status, balance INTO v_status, v_balance
        FROM subscribers WHERE subscriber_id = p_subscriber_id FOR UPDATE;

        UPDATE subscribers SET balance = balance + p_amount, updated_at = SYSTIMESTAMP
        WHERE subscriber_id = p_subscriber_id;

        COMMIT;

        p_result_code := c_ok;
        p_result_msg  := 'Bakiye yuklendi. Yeni bakiye: ' || TO_CHAR(v_balance + p_amount);
        pkg_vas_audit.log_action('TOPUP', 'SUBSCRIBER', p_subscriber_id, NULL, NULL, NULL,
            p_performed_by, 'SUCCESS', p_result_msg, NULL);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            ROLLBACK;
            p_result_code := c_err_subscriber;
            p_result_msg  := 'Abone bulunamadi: ' || p_subscriber_id;
            pkg_vas_audit.log_action('TOPUP', 'SUBSCRIBER', p_subscriber_id, NULL, NULL, NULL,
                p_performed_by, 'FAILURE', p_result_msg, NULL);
    END topup_balance;

    PROCEDURE subscribe (
        p_subscriber_id     IN NUMBER,
        p_service_id        IN NUMBER,
        p_performed_by      IN VARCHAR2 DEFAULT 'SYSTEM',
        p_subscription_id   OUT NUMBER,
        p_result_code       OUT VARCHAR2,
        p_result_msg        OUT VARCHAR2
    ) IS
        v_sub_status   subscribers.status%TYPE;
        v_sub_balance  subscribers.balance%TYPE;
        v_svc_status   services.status%TYPE;
        v_svc_type     services.service_type%TYPE;
        v_svc_price    services.price%TYPE;
        v_svc_code     services.service_code%TYPE;
        v_dup_cnt      NUMBER;
        v_new_id       NUMBER;
    BEGIN
        p_subscription_id := NULL;
        p_result_code := c_err_system;
        p_result_msg  := 'Islem basarisiz';

      
        BEGIN
            SELECT status, balance INTO v_sub_status, v_sub_balance
            FROM subscribers WHERE subscriber_id = p_subscriber_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
                p_result_code := c_err_subscriber;
                p_result_msg  := 'Abone bulunamadi (ID: ' || p_subscriber_id || ')';
                pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                    NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
                RETURN;
        END;

        IF v_sub_status <> 'ACTIVE' THEN
            ROLLBACK;
            p_result_code := c_err_sub_inact;
            p_result_msg  := 'Abone aktif degil (ID: ' || p_subscriber_id || ', durum: ' || v_sub_status || ')';
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

       
        BEGIN
            SELECT status, service_type, price, service_code
            INTO v_svc_status, v_svc_type, v_svc_price, v_svc_code
            FROM services WHERE service_id = p_service_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
                p_result_code := c_err_service;
                p_result_msg  := 'Servis bulunamadi (ID: ' || p_service_id || ')';
                pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                    NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
                RETURN;
        END;

        IF v_svc_status <> 'ACTIVE' THEN
            ROLLBACK;
            p_result_code := c_err_svc_inact;
            p_result_msg  := 'Servis aktif degil: ' || v_svc_code;
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        IF v_svc_type <> 'SUBSCRIPTION' THEN
            ROLLBACK;
            p_result_code := c_err_wrong_type;
            p_result_msg  := 'Bu servis subscription tipi degil: ' || v_svc_code;
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

      
        SELECT COUNT(*) INTO v_dup_cnt
        FROM subscriptions
        WHERE subscriber_id = p_subscriber_id
          AND service_id = p_service_id
          AND status = 'ACTIVE';

        IF v_dup_cnt > 0 THEN
            ROLLBACK;
            p_result_code := c_err_duplicate;
            p_result_msg  := 'Bu abonenin bu servis icin zaten aktif subscription var. Iptal etmeden tekrar alinamaz.';
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg,
                '{"reason":"DUPLICATE_SUBSCRIPTION"}');
            RETURN;
        END IF;

      
        IF v_sub_balance < v_svc_price THEN
            ROLLBACK;
            p_result_code := c_err_balance;
            p_result_msg  := 'Yetersiz bakiye. Gerekli: ' || v_svc_price || ', Mevcut: ' || v_sub_balance;
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        UPDATE subscribers
        SET balance = balance - v_svc_price, updated_at = SYSTIMESTAMP
        WHERE subscriber_id = p_subscriber_id;

        v_new_id := seq_subscription.NEXTVAL;
        INSERT INTO subscriptions (subscription_id, subscriber_id, service_id, status, price_charged)
        VALUES (v_new_id, p_subscriber_id, p_service_id, 'ACTIVE', v_svc_price);

        COMMIT;

        p_subscription_id := v_new_id;
        p_result_code := c_ok;
        p_result_msg  := 'Subscription aktif edildi: ' || v_svc_code || ' (ID: ' || v_new_id || ')';

        pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
            v_new_id, 'SUBSCRIPTION', p_performed_by, 'SUCCESS', p_result_msg, NULL);

    EXCEPTION
        WHEN DUP_VAL_ON_INDEX THEN
            ROLLBACK;
            p_subscription_id := NULL;
            p_result_code := c_err_duplicate;
            p_result_msg  := 'Duplicate engellendi (DB index): Bu servis zaten aktif.';
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg,
                '{"reason":"DB_UNIQUE_CONSTRAINT"}');
        WHEN OTHERS THEN
            ROLLBACK;
            p_result_code := c_err_system;
            p_result_msg  := SQLERRM;
            pkg_vas_audit.log_action('SUBSCRIBE', 'SUBSCRIPTION', p_subscriber_id, p_service_id,
                NULL, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
    END subscribe;

    PROCEDURE cancel_subscription (
        p_subscription_id IN NUMBER,
        p_performed_by    IN VARCHAR2 DEFAULT 'SYSTEM',
        p_result_code     OUT VARCHAR2,
        p_result_msg      OUT VARCHAR2
    ) IS
        v_status subscriptions.status%TYPE;
        v_sub_id subscriptions.subscriber_id%TYPE;
        v_svc_id subscriptions.service_id%TYPE;
    BEGIN
        BEGIN
            SELECT status, subscriber_id, service_id
            INTO v_status, v_sub_id, v_svc_id
            FROM subscriptions WHERE subscription_id = p_subscription_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                p_result_code := c_err_not_found;
                p_result_msg  := 'Subscription bulunamadi: ' || p_subscription_id;
                pkg_vas_audit.log_action('CANCEL_SUBSCRIPTION', 'SUBSCRIPTION', NULL, NULL,
                    p_subscription_id, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
                RETURN;
        END;

        IF v_status <> 'ACTIVE' THEN
            p_result_code := c_err_not_active;
            p_result_msg  := 'Subscription zaten iptal edilmis veya aktif degil';
            pkg_vas_audit.log_action('CANCEL_SUBSCRIPTION', 'SUBSCRIPTION', v_sub_id, v_svc_id,
                p_subscription_id, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        UPDATE subscriptions
        SET status = 'CANCELLED', cancelled_at = SYSTIMESTAMP
        WHERE subscription_id = p_subscription_id;

        COMMIT;

        p_result_code := c_ok;
        p_result_msg  := 'Subscription iptal edildi: ' || p_subscription_id;
        pkg_vas_audit.log_action('CANCEL_SUBSCRIPTION', 'SUBSCRIPTION', v_sub_id, v_svc_id,
            p_subscription_id, 'SUBSCRIPTION', p_performed_by, 'SUCCESS', p_result_msg, NULL);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_result_code := c_err_system;
            p_result_msg  := SQLERRM;
            pkg_vas_audit.log_action('CANCEL_SUBSCRIPTION', 'SUBSCRIPTION', NULL, NULL,
                p_subscription_id, 'SUBSCRIPTION', p_performed_by, 'FAILURE', p_result_msg, NULL);
    END cancel_subscription;

    PROCEDURE purchase_one_time (
        p_subscriber_id IN NUMBER,
        p_service_id    IN NUMBER,
        p_performed_by  IN VARCHAR2 DEFAULT 'SYSTEM',
        p_purchase_id   OUT NUMBER,
        p_result_code   OUT VARCHAR2,
        p_result_msg    OUT VARCHAR2
    ) IS
        v_sub_status  subscribers.status%TYPE;
        v_sub_balance subscribers.balance%TYPE;
        v_svc_status  services.status%TYPE;
        v_svc_type    services.service_type%TYPE;
        v_svc_price   services.price%TYPE;
        v_svc_code    services.service_code%TYPE;
        v_new_id      NUMBER;
        v_prev_cnt    NUMBER;
    BEGIN
        p_purchase_id := NULL;

        BEGIN
            SELECT status, balance INTO v_sub_status, v_sub_balance
            FROM subscribers WHERE subscriber_id = p_subscriber_id FOR UPDATE;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
                p_result_code := c_err_subscriber;
                p_result_msg  := 'Abone bulunamadi: ' || p_subscriber_id;
                pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                    NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
                RETURN;
        END;

        IF v_sub_status <> 'ACTIVE' THEN
            ROLLBACK;
            p_result_code := c_err_sub_inact;
            p_result_msg  := 'Abone aktif degil';
            pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        BEGIN
            SELECT status, service_type, price, service_code
            INTO v_svc_status, v_svc_type, v_svc_price, v_svc_code
            FROM services WHERE service_id = p_service_id;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                ROLLBACK;
                p_result_code := c_err_service;
                p_result_msg  := 'Servis bulunamadi';
                pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                    NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
                RETURN;
        END;

        IF v_svc_status <> 'ACTIVE' THEN
            ROLLBACK;
            p_result_code := c_err_svc_inact;
            p_result_msg  := 'Servis aktif degil: ' || v_svc_code;
            pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        IF v_svc_type <> 'ONE_TIME' THEN
            ROLLBACK;
            p_result_code := c_err_wrong_type;
            p_result_msg  := 'Bu servis one-time tipi degil';
            pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

        IF v_sub_balance < v_svc_price THEN
            ROLLBACK;
            p_result_code := c_err_balance;
            p_result_msg  := 'Yetersiz bakiye';
            pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
            RETURN;
        END IF;

      
        SELECT COUNT(*) INTO v_prev_cnt
        FROM one_time_purchases
        WHERE subscriber_id = p_subscriber_id AND service_id = p_service_id;

        UPDATE subscribers
        SET balance = balance - v_svc_price, updated_at = SYSTIMESTAMP
        WHERE subscriber_id = p_subscriber_id;

        v_new_id := seq_one_time.NEXTVAL;
        INSERT INTO one_time_purchases (purchase_id, subscriber_id, service_id, amount)
        VALUES (v_new_id, p_subscriber_id, p_service_id, v_svc_price);

        COMMIT;

        p_purchase_id := v_new_id;
        p_result_code := c_ok;
        p_result_msg  := 'One-time satin alindi: ' || v_svc_code || ' (satis #' || (v_prev_cnt + 1) || ')';

        pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
            v_new_id, 'ONE_TIME', p_performed_by, 'SUCCESS', p_result_msg, NULL);

    EXCEPTION
        WHEN OTHERS THEN
            ROLLBACK;
            p_result_code := c_err_system;
            p_result_msg  := SQLERRM;
            pkg_vas_audit.log_action('PURCHASE_ONE_TIME', 'ONE_TIME', p_subscriber_id, p_service_id,
                NULL, 'ONE_TIME', p_performed_by, 'FAILURE', p_result_msg, NULL);
    END purchase_one_time;

    PROCEDURE validate_login (
        p_username    IN VARCHAR2,
        p_password    IN VARCHAR2,
        p_user_id     OUT NUMBER,
        p_display_name OUT VARCHAR2,
        p_result_code OUT VARCHAR2,
        p_result_msg  OUT VARCHAR2
    ) IS
    BEGIN
        p_user_id := NULL;
        SELECT user_id, display_name INTO p_user_id, p_display_name
        FROM app_users
        WHERE UPPER(username) = UPPER(TRIM(p_username))
          AND password_hash = TRIM(p_password)
          AND status = 'ACTIVE';

        UPDATE app_users SET last_login_at = SYSTIMESTAMP WHERE user_id = p_user_id;
        COMMIT;

        p_result_code := c_ok;
        p_result_msg  := 'Giris basarili';

        pkg_vas_audit.log_action('LOGIN', 'AUTH', NULL, NULL, p_user_id, 'APP_USER',
            p_username, 'SUCCESS', 'Kullanici girisi', NULL);

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            p_user_id := NULL;
            p_display_name := NULL;
            p_result_code := c_err_login;
            p_result_msg  := 'Kullanici adi veya sifre hatali';
            pkg_vas_audit.log_action('LOGIN', 'AUTH', NULL, NULL, NULL, 'APP_USER',
                p_username, 'FAILURE', p_result_msg, NULL);
    END validate_login;

END pkg_vas_core;
/


CREATE OR REPLACE PACKAGE pkg_vas_reports AS
    PROCEDURE report_best_selling (
        p_json OUT CLOB
    );

    PROCEDURE report_active_subscriptions (
        p_total OUT NUMBER,
        p_json  OUT CLOB
    );

    PROCEDURE report_revenue (
        p_period   IN VARCHAR2,
        p_total    OUT NUMBER,
        p_sub_rev  OUT NUMBER,
        p_ot_rev   OUT NUMBER
    );

    PROCEDURE report_sales_performance (
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_json       OUT CLOB
    );

    PROCEDURE get_audit_logs (
        p_limit IN NUMBER DEFAULT 100,
        p_json  OUT CLOB
    );
END pkg_vas_reports;
/

CREATE OR REPLACE PACKAGE BODY pkg_vas_reports AS

  PROCEDURE init_json_array (p_json OUT CLOB) IS
  BEGIN
    p_json := TO_CLOB('[]');
  END init_json_array;

  PROCEDURE finalize_json_array (p_json IN OUT CLOB) IS
  BEGIN
    IF p_json IS NULL THEN
      p_json := TO_CLOB('[]');
    END IF;
  END finalize_json_array;

    PROCEDURE report_best_selling (p_json OUT CLOB) IS
    BEGIN
        init_json_array(p_json);
        BEGIN
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'SERVICE_ID' VALUE service_id,
                    'SERVICE_CODE' VALUE service_code,
                    'SERVICE_NAME' VALUE service_name,
                    'SERVICE_TYPE' VALUE service_type,
                    'TOTAL_SALES' VALUE total_sales,
                    'TOTAL_REVENUE' VALUE total_revenue
                )
                ORDER BY total_sales DESC, total_revenue DESC
                RETURNING CLOB
            ) INTO p_json
            FROM (
                SELECT service_id, service_code, service_name, service_type,
                       total_sales, total_revenue
                FROM (
                    SELECT s.service_id, s.service_code, s.service_name, s.service_type,
                           COUNT(*) AS total_sales,
                           SUM(sales.amount) AS total_revenue
                    FROM (
                        SELECT service_id, price_charged AS amount FROM subscriptions
                        UNION ALL
                        SELECT service_id, amount FROM one_time_purchases
                    ) sales
                    JOIN services s ON s.service_id = sales.service_id
                    GROUP BY s.service_id, s.service_code, s.service_name, s.service_type
                    ORDER BY total_sales DESC, total_revenue DESC
                )
                WHERE ROWNUM <= 20
            );
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                init_json_array(p_json);
        END;
        finalize_json_array(p_json);
    END report_best_selling;

    PROCEDURE report_active_subscriptions (
        p_total OUT NUMBER,
        p_json  OUT CLOB
    ) IS
    BEGIN
        SELECT COUNT(*) INTO p_total FROM subscriptions WHERE status = 'ACTIVE';

        init_json_array(p_json);
        BEGIN
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'SUBSCRIPTION_ID' VALUE subscription_id,
                    'SUBSCRIBER_ID' VALUE subscriber_id,
                    'MSISDN' VALUE msisdn,
                    'FULL_NAME' VALUE full_name,
                    'SERVICE_CODE' VALUE service_code,
                    'SERVICE_NAME' VALUE service_name,
                    'PRICE_CHARGED' VALUE price_charged,
                    'STARTED_AT' VALUE TO_CHAR(started_at, 'YYYY-MM-DD"T"HH24:MI:SS')
                )
                ORDER BY started_at DESC
                RETURNING CLOB
            ) INTO p_json
            FROM (
                SELECT sub.subscription_id, sub.subscriber_id, s.msisdn, s.full_name,
                       srv.service_code, srv.service_name, sub.price_charged, sub.started_at
                FROM subscriptions sub
                JOIN subscribers s ON s.subscriber_id = sub.subscriber_id
                JOIN services srv ON srv.service_id = sub.service_id
                WHERE sub.status = 'ACTIVE'
            );
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                init_json_array(p_json);
        END;
        finalize_json_array(p_json);
    END report_active_subscriptions;

    PROCEDURE report_revenue (
        p_period   IN VARCHAR2,
        p_total    OUT NUMBER,
        p_sub_rev  OUT NUMBER,
        p_ot_rev   OUT NUMBER
    ) IS
        v_from TIMESTAMP;
    BEGIN
        CASE UPPER(p_period)
            WHEN '24H' THEN v_from := SYSTIMESTAMP - NUMTODSINTERVAL(24, 'HOUR');
            WHEN 'WEEK' THEN v_from := SYSTIMESTAMP - NUMTODSINTERVAL(7, 'DAY');
            WHEN 'MONTH' THEN v_from := ADD_MONTHS(SYSTIMESTAMP, -1);
            ELSE v_from := SYSTIMESTAMP - NUMTODSINTERVAL(24, 'HOUR');
        END CASE;

        SELECT NVL(SUM(price_charged), 0) INTO p_sub_rev
        FROM subscriptions
        WHERE started_at >= v_from;

        SELECT NVL(SUM(amount), 0) INTO p_ot_rev
        FROM one_time_purchases
        WHERE purchased_at >= v_from;

        p_total := p_sub_rev + p_ot_rev;

        pkg_vas_audit.log_action('REPORT_REVENUE', 'REPORT', NULL, NULL, NULL, NULL,
            'SYSTEM', 'INFO', 'Ciro raporu: ' || p_period,
            '{"period":"' || p_period || '","total":' || p_total || '}');
    END report_revenue;

    PROCEDURE report_sales_performance (
        p_start_date IN DATE,
        p_end_date   IN DATE,
        p_json       OUT CLOB
    ) IS
    BEGIN
        init_json_array(p_json);
        BEGIN
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'SALE_DATE' VALUE TO_CHAR(sale_date, 'YYYY-MM-DD'),
                    'TRANSACTION_COUNT' VALUE transaction_count,
                    'DAILY_REVENUE' VALUE daily_revenue,
                    'DAY_TYPE' VALUE day_type
                )
                ORDER BY sale_date
                RETURNING CLOB
            ) INTO p_json
            FROM (
                WITH date_range AS (
                    SELECT TRUNC(p_start_date) + LEVEL - 1 AS sale_date
                    FROM dual
                    CONNECT BY TRUNC(p_start_date) + LEVEL - 1 <= TRUNC(p_end_date)
                ),
                business_days AS (
                    SELECT sale_date
                    FROM date_range
                    WHERE TO_CHAR(sale_date, 'DY', 'NLS_DATE_LANGUAGE=ENGLISH') NOT IN ('SAT', 'SUN')
                ),
                daily_sub AS (
                    SELECT TRUNC(started_at) AS d, COUNT(*) cnt, SUM(price_charged) rev
                    FROM subscriptions
                    GROUP BY TRUNC(started_at)
                ),
                daily_ot AS (
                    SELECT TRUNC(purchased_at) AS d, COUNT(*) cnt, SUM(amount) rev
                    FROM one_time_purchases
                    GROUP BY TRUNC(purchased_at)
                )
                SELECT bd.sale_date,
                       NVL(ds.cnt, 0) + NVL(dot.cnt, 0) AS transaction_count,
                       NVL(ds.rev, 0) + NVL(dot.rev, 0) AS daily_revenue,
                       'BUSINESS_DAY' AS day_type
                FROM business_days bd
                LEFT JOIN daily_sub ds ON ds.d = bd.sale_date
                LEFT JOIN daily_ot dot ON dot.d = bd.sale_date
            );
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                init_json_array(p_json);
        END;
        finalize_json_array(p_json);
    END report_sales_performance;

    PROCEDURE get_audit_logs (
        p_limit IN NUMBER DEFAULT 100,
        p_json  OUT CLOB
    ) IS
    BEGIN
        init_json_array(p_json);
        BEGIN
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'LOG_ID' VALUE log_id,
                    'ACTION_CODE' VALUE action_code,
                    'ACTION_CATEGORY' VALUE action_category,
                    'SUBSCRIBER_ID' VALUE subscriber_id,
                    'SERVICE_ID' VALUE service_id,
                    'REFERENCE_ID' VALUE reference_id,
                    'PERFORMED_BY' VALUE performed_by,
                    'STATUS_RESULT' VALUE status_result,
                    'MESSAGE' VALUE message,
                    'DETAIL_JSON' VALUE detail_json,
                    'IP_ADDRESS' VALUE ip_address,
                    'CREATED_AT' VALUE TO_CHAR(created_at, 'YYYY-MM-DD"T"HH24:MI:SS')
                )
                ORDER BY created_at DESC
                RETURNING CLOB
            ) INTO p_json
            FROM (
                SELECT log_id, action_code, action_category, subscriber_id, service_id,
                       reference_id, performed_by, status_result, message, detail_json,
                       ip_address, created_at
                FROM (
                    SELECT log_id, action_code, action_category, subscriber_id, service_id,
                           reference_id, performed_by, status_result, message, detail_json,
                           ip_address, created_at
                    FROM audit_logs
                    ORDER BY created_at DESC
                )
                WHERE ROWNUM <= NVL(p_limit, 100)
            );
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                init_json_array(p_json);
        END;
        finalize_json_array(p_json);
    END get_audit_logs;

END pkg_vas_reports;
/
