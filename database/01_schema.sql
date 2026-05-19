
CREATE SEQUENCE seq_subscriber      START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_service         START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_subscription    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_one_time        START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_audit_log       START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_app_user        START WITH 1 INCREMENT BY 1 NOCACHE;


CREATE TABLE subscribers (
    subscriber_id   NUMBER(12)      NOT NULL,
    msisdn          VARCHAR2(15)    NOT NULL,
    full_name       VARCHAR2(200)   NOT NULL,
    balance         NUMBER(14,2)    DEFAULT 0 NOT NULL,
    status          VARCHAR2(20)    DEFAULT 'ACTIVE' NOT NULL,
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_subscribers PRIMARY KEY (subscriber_id),
    CONSTRAINT uk_subscribers_msisdn UNIQUE (msisdn),
    CONSTRAINT chk_subscribers_status CHECK (status IN ('ACTIVE', 'INACTIVE')),
    CONSTRAINT chk_subscribers_balance CHECK (balance >= 0)
);

CREATE INDEX idx_subscribers_status ON subscribers (status);


CREATE TABLE services (
    service_id      NUMBER(12)      NOT NULL,
    service_code    VARCHAR2(50)    NOT NULL,
    service_name    VARCHAR2(200)   NOT NULL,
    service_type    VARCHAR2(20)    NOT NULL,
    price           NUMBER(12,2)    NOT NULL,
    status          VARCHAR2(20)    DEFAULT 'ACTIVE' NOT NULL,
    description     VARCHAR2(500),
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    updated_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_services PRIMARY KEY (service_id),
    CONSTRAINT uk_services_code UNIQUE (service_code),
    CONSTRAINT chk_services_type CHECK (service_type IN ('SUBSCRIPTION', 'ONE_TIME')),
    CONSTRAINT chk_services_status CHECK (status IN ('ACTIVE', 'INACTIVE')),
    CONSTRAINT chk_services_price CHECK (price > 0)
);

CREATE INDEX idx_services_type_status ON services (service_type, status);


CREATE TABLE subscriptions (
    subscription_id NUMBER(12)      NOT NULL,
    subscriber_id   NUMBER(12)      NOT NULL,
    service_id      NUMBER(12)      NOT NULL,
    status          VARCHAR2(20)    DEFAULT 'ACTIVE' NOT NULL,
    price_charged   NUMBER(12,2)    NOT NULL,
    started_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    cancelled_at    TIMESTAMP,
    created_at      TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_subscriptions PRIMARY KEY (subscription_id),
    CONSTRAINT fk_sub_subscriber FOREIGN KEY (subscriber_id)
        REFERENCES subscribers (subscriber_id),
    CONSTRAINT fk_sub_service FOREIGN KEY (service_id)
        REFERENCES services (service_id),
    CONSTRAINT chk_sub_status CHECK (status IN ('ACTIVE', 'CANCELLED'))
);

CREATE UNIQUE INDEX uk_sub_active_unique
    ON subscriptions (
        CASE WHEN status = 'ACTIVE' THEN subscriber_id END,
        CASE WHEN status = 'ACTIVE' THEN service_id END
    );

CREATE INDEX idx_sub_subscriber ON subscriptions (subscriber_id, status);
CREATE INDEX idx_sub_service ON subscriptions (service_id, status);
CREATE INDEX idx_sub_started ON subscriptions (started_at);


CREATE TABLE one_time_purchases (
    purchase_id     NUMBER(12)      NOT NULL,
    subscriber_id   NUMBER(12)      NOT NULL,
    service_id      NUMBER(12)      NOT NULL,
    amount          NUMBER(12,2)    NOT NULL,
    purchased_at    TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_one_time PRIMARY KEY (purchase_id),
    CONSTRAINT fk_ot_subscriber FOREIGN KEY (subscriber_id)
        REFERENCES subscribers (subscriber_id),
    CONSTRAINT fk_ot_service FOREIGN KEY (service_id)
        REFERENCES services (service_id),
    CONSTRAINT chk_ot_amount CHECK (amount > 0)
);

CREATE INDEX idx_ot_subscriber ON one_time_purchases (subscriber_id);
CREATE INDEX idx_ot_service ON one_time_purchases (service_id);
CREATE INDEX idx_ot_purchased ON one_time_purchases (purchased_at);


CREATE TABLE audit_logs (
    log_id            NUMBER(12)      NOT NULL,
    action_code       VARCHAR2(50)    NOT NULL,
    action_category   VARCHAR2(30)    NOT NULL,
    subscriber_id     NUMBER(12),
    service_id        NUMBER(12),
    reference_id      NUMBER(12),
    reference_type    VARCHAR2(30),
    performed_by      VARCHAR2(100),
    status_result     VARCHAR2(20)    NOT NULL,
    message           VARCHAR2(1000),
    detail_json       VARCHAR2(4000),
    ip_address        VARCHAR2(45),
    log_level         VARCHAR2(20),
    response_code     VARCHAR2(50),
    created_at        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_audit_logs PRIMARY KEY (log_id),
    CONSTRAINT chk_audit_status CHECK (status_result IN ('SUCCESS', 'FAILURE', 'INFO'))
);

CREATE INDEX idx_audit_created ON audit_logs (created_at);
CREATE INDEX idx_audit_subscriber ON audit_logs (subscriber_id);
CREATE INDEX idx_audit_action ON audit_logs (action_code, created_at);


CREATE TABLE app_users (
    user_id           NUMBER(12)      NOT NULL,
    username          VARCHAR2(50)    NOT NULL,
    password_hash     VARCHAR2(256)   NOT NULL,
    display_name      VARCHAR2(100),
    role_name         VARCHAR2(30)    DEFAULT 'OPERATOR' NOT NULL,
    status            VARCHAR2(20)    DEFAULT 'ACTIVE' NOT NULL,
    last_login_at     TIMESTAMP,
    created_at        TIMESTAMP       DEFAULT SYSTIMESTAMP NOT NULL,
    CONSTRAINT pk_app_users PRIMARY KEY (user_id),
    CONSTRAINT uk_app_users_username UNIQUE (username),
    CONSTRAINT chk_app_users_status CHECK (status IN ('ACTIVE', 'INACTIVE'))
);

COMMIT;
