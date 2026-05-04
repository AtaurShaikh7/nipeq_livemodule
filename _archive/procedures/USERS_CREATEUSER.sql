PROCEDURE USERS_CREATEUSER (

    p_Fname IN VARCHAR2,

    p_Lname IN VARCHAR2,

    p_Email IN VARCHAR2,

    p_Password IN VARCHAR2

)

AS

    v_login_id NUMBER;

    v_full_name VARCHAR2(200);

    v_count NUMBER;

BEGIN 

--    -- Generate next LOGIN_ID

--    SELECT NVL(MAX(LOGIN_ID), 999999999) + 1 

--    INTO v_login_id 

--    FROM USERS;



    -- Create full name

    v_full_name := p_Fname || ' ' || p_Lname;



    -- Check if email already exists

    SELECT COUNT(*) 

    INTO v_count 

    FROM USERS 

    WHERE UPPER(EMAIL_ID) = UPPER(p_Email);



    IF v_count > 0 THEN

        RAISE_APPLICATION_ERROR(-20001, 'Email already exists');

    END IF;



    -- Insert new user

    INSERT INTO USERS (

        FIRST_NAME,

        LAST_NAME,

        LOGIN_ID,

        PASSWORD,

        ROLE_ID,

        DEFAULT_FUND_ID,

        ASSOCIATED_FUNDS,

        LAST_LOGIN,

        VAN_ACCESS,

        FULL_NAME,

        ANALYST_FLAG,

        EMAIL_ID

    ) VALUES (

        p_Fname,

        p_Lname,

        '-',

        p_Password,

        2,                    -- Default role

        1,                   -- Default fund

        1,                   -- Default associated funds

        NULL,              -- Current date

        1,                    -- Default access

        v_full_name,

        1,                    -- Default analyst flag

        p_Email

    );



    COMMIT;



    -- Return success message or user ID

    DBMS_OUTPUT.PUT_LINE('User created successfully with LOGIN_ID: ' || v_login_id);



EXCEPTION

    WHEN OTHERS THEN

        ROLLBACK;

        RAISE_APPLICATION_ERROR(-20002, 'Error creating user: ' || SQLERRM);

END USERS_CREATEUSER;

