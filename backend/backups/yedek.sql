--
-- PostgreSQL database dump
--

\restrict JngoKsR7Oreb9dFSULRoDVuzUd6JjdWD49aa9xITkOeyJkWT9szQzA1OOJ3EVQS

-- Dumped from database version 18.3
-- Dumped by pg_dump version 18.3

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: categories; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.categories (
    id bigint NOT NULL,
    name character varying(100) NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    printer_route character varying(20) DEFAULT 'MUTFAK'::character varying NOT NULL,
    image_path character varying(255),
    CONSTRAINT categories_printer_route_check CHECK (((printer_route)::text = ANY ((ARRAY['MUTFAK'::character varying, 'BAR'::character varying, 'KASA'::character varying])::text[])))
);


ALTER TABLE public.categories OWNER TO postgres;

--
-- Name: categories_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.categories_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.categories_id_seq OWNER TO postgres;

--
-- Name: categories_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.categories_id_seq OWNED BY public.categories.id;


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.expenses (
    id bigint NOT NULL,
    expense_date date DEFAULT CURRENT_DATE NOT NULL,
    item_name character varying(160) NOT NULL,
    quantity numeric(10,2) NOT NULL,
    unit_price numeric(12,2) NOT NULL,
    total_amount numeric(12,2) NOT NULL,
    note text,
    created_by_user_id bigint,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT expenses_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT expenses_total_amount_check CHECK ((total_amount >= (0)::numeric)),
    CONSTRAINT expenses_unit_price_check CHECK ((unit_price >= (0)::numeric))
);


ALTER TABLE public.expenses OWNER TO postgres;

--
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.expenses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.expenses_id_seq OWNER TO postgres;

--
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.expenses_id_seq OWNED BY public.expenses.id;


--
-- Name: order_items; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.order_items (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    product_id bigint NOT NULL,
    product_name_snapshot character varying(140) NOT NULL,
    unit_price_snapshot numeric(12,2) NOT NULL,
    quantity numeric(10,2) NOT NULL,
    line_total numeric(12,2) NOT NULL,
    item_status character varying(20) DEFAULT 'PENDING'::character varying NOT NULL,
    note text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    category_snapshot character varying(100),
    printer_route_snapshot character varying(20) DEFAULT 'MUTFAK'::character varying NOT NULL,
    CONSTRAINT order_items_item_status_check CHECK (((item_status)::text = ANY ((ARRAY['PENDING'::character varying, 'SENT'::character varying, 'PAID'::character varying, 'VOID'::character varying])::text[]))),
    CONSTRAINT order_items_line_total_check CHECK ((line_total >= (0)::numeric)),
    CONSTRAINT order_items_printer_route_snapshot_check CHECK (((printer_route_snapshot)::text = ANY ((ARRAY['MUTFAK'::character varying, 'BAR'::character varying, 'KASA'::character varying])::text[]))),
    CONSTRAINT order_items_quantity_check CHECK ((quantity > (0)::numeric)),
    CONSTRAINT order_items_unit_price_snapshot_check CHECK ((unit_price_snapshot >= (0)::numeric))
);


ALTER TABLE public.order_items OWNER TO postgres;

--
-- Name: order_items_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.order_items_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.order_items_id_seq OWNER TO postgres;

--
-- Name: order_items_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.order_items_id_seq OWNED BY public.order_items.id;


--
-- Name: orders; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.orders (
    id bigint NOT NULL,
    table_id bigint NOT NULL,
    waiter_id bigint NOT NULL,
    opened_by_user_id bigint NOT NULL,
    closed_by_user_id bigint,
    order_status character varying(20) DEFAULT 'OPEN'::character varying NOT NULL,
    note text,
    subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    discount_total numeric(12,2) DEFAULT 0 NOT NULL,
    grand_total numeric(12,2) DEFAULT 0 NOT NULL,
    opened_at timestamp with time zone DEFAULT now() NOT NULL,
    confirmed_at timestamp with time zone,
    closed_at timestamp with time zone,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    payment_method character varying(20),
    guest_count integer DEFAULT 1 NOT NULL,
    table_note text,
    payment_lock_user_id integer,
    payment_lock_at timestamp with time zone,
    CONSTRAINT orders_discount_total_check CHECK ((discount_total >= (0)::numeric)),
    CONSTRAINT orders_grand_total_check CHECK ((grand_total >= (0)::numeric)),
    CONSTRAINT orders_guest_count_check CHECK ((guest_count > 0)),
    CONSTRAINT orders_order_status_check CHECK (((order_status)::text = ANY ((ARRAY['OPEN'::character varying, 'CONFIRMED'::character varying, 'PAID'::character varying, 'CANCELLED'::character varying])::text[]))),
    CONSTRAINT orders_payment_method_check CHECK (((payment_method)::text = ANY ((ARRAY['CASH'::character varying, 'CARD'::character varying, 'MIXED'::character varying, 'OTHER'::character varying])::text[]))),
    CONSTRAINT orders_subtotal_check CHECK ((subtotal >= (0)::numeric))
);


ALTER TABLE public.orders OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.orders_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.orders_id_seq OWNER TO postgres;

--
-- Name: orders_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.orders_id_seq OWNED BY public.orders.id;


--
-- Name: payments; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.payments (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    received_by_user_id bigint NOT NULL,
    payment_method character varying(20) NOT NULL,
    amount numeric(12,2) NOT NULL,
    currency character varying(3) DEFAULT 'TRY'::character varying NOT NULL,
    payment_note text,
    paid_at timestamp with time zone DEFAULT now() NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    discount_amount numeric(12,2) DEFAULT 0 NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT payments_amount_check CHECK ((amount > (0)::numeric)),
    CONSTRAINT payments_discount_amount_check CHECK ((discount_amount >= (0)::numeric)),
    CONSTRAINT payments_payment_method_check CHECK (((payment_method)::text = ANY ((ARRAY['CASH'::character varying, 'CARD'::character varying, 'MIXED'::character varying, 'OTHER'::character varying])::text[])))
);


ALTER TABLE public.payments OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.payments_id_seq OWNER TO postgres;

--
-- Name: payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.payments_id_seq OWNED BY public.payments.id;


--
-- Name: products; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.products (
    id bigint NOT NULL,
    category_id bigint NOT NULL,
    name character varying(140) NOT NULL,
    sku character varying(60),
    price numeric(12,2) NOT NULL,
    vat_rate numeric(5,2) DEFAULT 10.00 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    category character varying(100),
    image_url character varying(500),
    CONSTRAINT products_price_check CHECK ((price >= (0)::numeric)),
    CONSTRAINT products_vat_rate_check CHECK ((vat_rate >= (0)::numeric))
);


ALTER TABLE public.products OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.products_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.products_id_seq OWNER TO postgres;

--
-- Name: products_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.products_id_seq OWNED BY public.products.id;


--
-- Name: tables; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.tables (
    id bigint NOT NULL,
    table_code character varying(20) NOT NULL,
    display_name character varying(80) NOT NULL,
    capacity integer DEFAULT 4 NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    zone character varying(60) DEFAULT 'Salon'::character varying NOT NULL,
    is_custom boolean DEFAULT false NOT NULL,
    CONSTRAINT tables_capacity_check CHECK ((capacity > 0))
);


ALTER TABLE public.tables OWNER TO postgres;

--
-- Name: tables_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.tables_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.tables_id_seq OWNER TO postgres;

--
-- Name: tables_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.tables_id_seq OWNED BY public.tables.id;


--
-- Name: users; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.users (
    id bigint NOT NULL,
    full_name character varying(120) NOT NULL,
    pin_code character varying(6) NOT NULL,
    role_id smallint NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT users_role_id_check CHECK ((role_id = ANY (ARRAY[1, 2])))
);


ALTER TABLE public.users OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.users_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.users_id_seq OWNER TO postgres;

--
-- Name: users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.users_id_seq OWNED BY public.users.id;


--
-- Name: voids; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.voids (
    id bigint NOT NULL,
    order_id bigint NOT NULL,
    order_item_id bigint,
    product_id bigint NOT NULL,
    action_type character varying(20) NOT NULL,
    quantity numeric(10,2) DEFAULT 0 NOT NULL,
    reason text,
    created_by_user_id bigint NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT voids_action_type_check CHECK (((action_type)::text = ANY ((ARRAY['VOID'::character varying, 'COMP'::character varying])::text[]))),
    CONSTRAINT voids_quantity_check CHECK ((quantity >= (0)::numeric))
);


ALTER TABLE public.voids OWNER TO postgres;

--
-- Name: voids_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.voids_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.voids_id_seq OWNER TO postgres;

--
-- Name: voids_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.voids_id_seq OWNED BY public.voids.id;


--
-- Name: z_reports; Type: TABLE; Schema: public; Owner: postgres
--

CREATE TABLE public.z_reports (
    id bigint NOT NULL,
    report_date date NOT NULL,
    total_revenue numeric(12,2) DEFAULT 0 NOT NULL,
    cash_total numeric(12,2) DEFAULT 0 NOT NULL,
    card_total numeric(12,2) DEFAULT 0 NOT NULL,
    total_orders integer DEFAULT 0 NOT NULL,
    total_subtotal numeric(12,2) DEFAULT 0 NOT NULL,
    total_vat numeric(12,2) DEFAULT 0 NOT NULL,
    generated_by_user_id bigint,
    payload jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);


ALTER TABLE public.z_reports OWNER TO postgres;

--
-- Name: z_reports_id_seq; Type: SEQUENCE; Schema: public; Owner: postgres
--

CREATE SEQUENCE public.z_reports_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.z_reports_id_seq OWNER TO postgres;

--
-- Name: z_reports_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: postgres
--

ALTER SEQUENCE public.z_reports_id_seq OWNED BY public.z_reports.id;


--
-- Name: categories id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories ALTER COLUMN id SET DEFAULT nextval('public.categories_id_seq'::regclass);


--
-- Name: expenses id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expenses ALTER COLUMN id SET DEFAULT nextval('public.expenses_id_seq'::regclass);


--
-- Name: order_items id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items ALTER COLUMN id SET DEFAULT nextval('public.order_items_id_seq'::regclass);


--
-- Name: orders id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders ALTER COLUMN id SET DEFAULT nextval('public.orders_id_seq'::regclass);


--
-- Name: payments id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments ALTER COLUMN id SET DEFAULT nextval('public.payments_id_seq'::regclass);


--
-- Name: products id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products ALTER COLUMN id SET DEFAULT nextval('public.products_id_seq'::regclass);


--
-- Name: tables id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tables ALTER COLUMN id SET DEFAULT nextval('public.tables_id_seq'::regclass);


--
-- Name: users id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users ALTER COLUMN id SET DEFAULT nextval('public.users_id_seq'::regclass);


--
-- Name: voids id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voids ALTER COLUMN id SET DEFAULT nextval('public.voids_id_seq'::regclass);


--
-- Name: z_reports id; Type: DEFAULT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_reports ALTER COLUMN id SET DEFAULT nextval('public.z_reports_id_seq'::regclass);


--
-- Data for Name: categories; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.categories (id, name, is_active, sort_order, created_at, updated_at, printer_route, image_path) FROM stdin;
32	SANDVİÇLER VE TOSTLAR	f	999	2026-03-27 19:13:37.246886+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
35	WRAPLER	f	999	2026-03-27 19:17:45.146346+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
106	NARGİLE	t	999	2026-03-30 18:03:25.645943+03	2026-03-30 21:17:05.265056+03	BAR	\N
24	SOĞUK İÇECEKLER	t	1	2026-03-22 18:28:23.448475+03	2026-03-30 21:18:37.029973+03	BAR	\N
25	ANA YEMEKLER	t	2	2026-03-22 18:28:23.448475+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
31	APERATİFLER	t	3	2026-03-27 19:11:59.295518+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
30	KAHVALTI VE BAŞLANGIÇLAR	t	9	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
26	DONDURMALAR	t	10	2026-03-22 18:28:23.448475+03	2026-03-30 21:18:37.029973+03	BAR	\N
36	KREPLER	t	11	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
38	MAKARNALAR	t	12	2026-03-27 19:22:20.93582+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
34	PİZZALAR	t	17	2026-03-27 19:17:04.931114+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
37	SALATALAR	t	19	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
27	FONDU-WAFFLE	t	25	2026-03-22 18:28:23.448475+03	2026-03-30 21:18:37.029973+03	BAR	\N
33	HAMBURGERLER	t	999	2026-03-27 19:14:33.862273+03	2026-04-06 23:16:42.958266+03	MUTFAK	\N
23	SICAK İÇECEKLER	f	1	2026-03-22 18:28:23.448475+03	2026-04-06 23:16:42.958266+03	MUTFAK	\N
40	Yöresel Serpme Kahvaltı	f	1	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
41	Kahvaltısız Yapamayanlar	f	2	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
42	Omlet	f	3	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
43	Menemen	f	4	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
44	Börekler	f	5	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
45	Atıştırmalıklar	f	6	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
46	Sandviçler / Tostlar	f	7	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
47	Burgerler	f	8	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
48	Pizzalar	f	9	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
49	Wrapler	f	10	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
50	Krepler	f	11	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
51	Salatalar	f	12	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
52	Makarnalar	f	13	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
53	Tavuk Yemekleri	f	14	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
54	Et Yemekleri	f	15	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
55	Klasik Türk Kahvesi Çeşitleri	f	16	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
56	Özel Türk Kahvesi Çeşitleri	f	17	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
57	Espressolu Kahve Çeşitleri	f	18	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
58	Filtre Kahve Çeşitleri	f	19	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
59	Aromalı Filtre Kahveler	f	20	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
60	Yöresel Kahveler	f	21	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
61	Yeni Nesil Kahveler	f	22	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
62	Frappeler	f	23	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
63	Alternatif Tatlar	f	24	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
64	Sıcak Çikolatalar	f	25	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
65	Çay	f	26	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
66	Bitkisel Çaylar	f	27	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
67	Doğal Harman Çayları	f	28	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
68	Meyveli Çaylar	f	29	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
69	Alternatif Soğuklar	f	30	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
70	Soğuk Kahveler	f	31	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
71	Meyveli Frozen	f	32	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
72	Milkshakes	f	33	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
73	Meşrubatlar	f	34	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
74	Detoks İçecekler	f	35	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
76	Waffle	f	37	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
77	Fondü & Meyve	f	38	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
78	Dondurmalar	f	39	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	MUTFAK	\N
79	Kokteyller	f	40	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	BAR	\N
80	Hediyelik Ürünler	f	41	2026-03-28 16:06:29.43773+03	2026-03-28 16:16:36.497667+03	KASA	\N
107	MATCHA (MAÇA)	t	999	2026-03-30 18:06:20.093981+03	2026-03-30 21:17:05.265056+03	BAR	\N
84	ÇAYLAR	t	4	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
85	TÜRK KAHVESİ ÇEŞİTLERİ	t	5	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
86	ESPRESSOLU KAHVELER	t	6	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
87	FİLTRE KAHVELER	t	7	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
88	FRAPPELER	t	8	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
93	MEŞRUBATLAR	t	13	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
94	MEYVELİ FROZENLER	t	14	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
95	MİLKSHAKELER	t	15	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
96	PASTA VE KEKLER	t	16	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
98	SAHLEP-SICAK ÇİKOLATA	t	18	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
100	SOĞUK KAHVELER	t	20	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
101	WRAPLAR	t	21	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	MUTFAK	\N
102	YENİ NESİL KAHVELER	t	22	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
103	DETOKS	t	23	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	BAR	\N
104	TAKE AWAY	t	24	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	KASA	\N
\.


--
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.expenses (id, expense_date, item_name, quantity, unit_price, total_amount, note, created_by_user_id, created_at, updated_at) FROM stdin;
1	2026-04-06	sa	1.00	4000.00	4000.00	\N	3	2026-04-06 22:05:30.596175+03	2026-04-06 22:05:30.596175+03
\.


--
-- Data for Name: order_items; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.order_items (id, order_id, product_id, product_name_snapshot, unit_price_snapshot, quantity, line_total, item_status, note, created_at, updated_at, category_snapshot, printer_route_snapshot) FROM stdin;
92	35	1414	Damla Sakızlı - Fındık Parçacıklı Salep	200.00	1.00	200.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
1	1	493	Berriscus	190.00	1.00	190.00	PAID	\N	2026-04-01 00:34:59.621133+03	2026-04-01 00:35:18.132576+03	SOĞUK İÇECEKLER	BAR
94	35	1416	Sıcak Çikolata	190.00	2.00	380.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
43	22	1252	Damla Sakızlı Türk Kahvesi	150.00	4.00	600.00	SENT	Orta Sekerli x1	2026-04-06 02:09:08.63318+03	2026-04-06 02:09:08.702327+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
44	22	1250	Menengiç Kahvesi	140.00	1.00	140.00	SENT	Orta Sekerli x1	2026-04-06 02:09:08.63318+03	2026-04-06 02:09:08.702327+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
45	22	1251	Leb-İ Derya Kahvesi	150.00	1.00	150.00	SENT	Sade x1	2026-04-06 02:09:08.63318+03	2026-04-06 02:09:08.702327+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
46	23	536	Çay	40.00	2.00	80.00	SENT	demli	2026-04-06 02:12:52.718483+03	2026-04-06 02:13:07.395473+03	ÇAYLAR	BAR
145	38	1461	ujjj	1.00	1.00	1.00	SENT	\N	2026-04-06 13:19:48.956025+03	2026-04-06 13:19:48.975971+03	SOĞUK İÇECEKLER	BAR
5	4	1164	Amsterdam	350.00	2.00	700.00	PAID	\N	2026-04-01 12:31:45.515955+03	2026-04-01 12:33:41.098409+03	NARGİLE	BAR
47	24	536	Çay	90.00	2.00	180.00	SENT	\N	2026-04-06 12:13:52.197964+03	2026-04-06 12:14:18.787369+03	ÇAYLAR	BAR
146	38	1458	deneemee	100.00	1.00	100.00	SENT	\N	2026-04-06 13:19:48.956025+03	2026-04-06 13:19:48.975971+03	SOĞUK İÇECEKLER	BAR
7	6	493	Berriscus	190.00	3.00	570.00	PAID	\N	2026-04-01 12:33:52.000242+03	2026-04-01 12:34:13.027052+03	SOĞUK İÇECEKLER	BAR
48	25	1252	Damla Sakızlı Türk Kahvesi	150.00	1.00	150.00	SENT	Az Sekerli x1	2026-04-06 12:20:05.426652+03	2026-04-06 12:20:05.475572+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
42	19	536	Çay	40.00	2.00	80.00	SENT	\N	2026-04-06 02:05:33.736851+03	2026-04-06 12:22:48.830004+03	ÇAYLAR	BAR
39	19	536	Çay	40.00	1.00	40.00	SENT	\N	2026-04-06 01:25:19.011916+03	2026-04-06 12:22:48.830004+03	ÇAYLAR	BAR
9	8	1303	Leb-i Derya Kahvaltı (Yöresel Kahvaltı)	800.00	1.00	800.00	SENT	\N	2026-04-01 12:36:14.677671+03	2026-04-01 12:36:14.690798+03	KAHVALTI VE BAŞLANGIÇLAR	MUTFAK
10	8	1309	İtalyan Kahvaltısı	200.00	1.00	200.00	SENT	\N	2026-04-01 12:36:14.677671+03	2026-04-01 12:36:14.690798+03	KAHVALTI VE BAŞLANGIÇLAR	MUTFAK
49	26	1251	Leb-İ Derya Kahvesi	150.00	2.00	300.00	SENT	Orta Sekerli x1	2026-04-06 12:23:41.676925+03	2026-04-06 12:23:41.695131+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
11	8	1416	Sıcak Çikolata	190.00	1.00	190.00	SENT	\N	2026-04-01 12:38:42.291039+03	2026-04-01 12:38:42.302392+03	SAHLEP-SICAK ÇİKOLATA	BAR
8	7	1460	çako	1.00	1.00	1.00	PAID	\N	2026-04-01 12:35:29.450091+03	2026-04-04 13:25:06.021476+03	SOĞUK İÇECEKLER	BAR
12	9	493	Berriscus	190.00	2.00	380.00	SENT	\N	2026-04-04 13:33:30.185829+03	2026-04-04 13:33:30.215173+03	SOĞUK İÇECEKLER	BAR
50	27	1254	Dağ Çilekli Türk Kahvesi	150.00	1.00	150.00	SENT	Cok Sekerli x1	2026-04-06 12:29:19.750838+03	2026-04-06 12:29:19.80043+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
150	41	536	Çay	50.00	1.00	50.00	SENT	kapalı x1	2026-04-06 20:31:28.357771+03	2026-04-06 20:32:29.037124+03	ÇAYLAR	BAR
51	28	1295	Colombian Supremo	190.00	1.00	190.00	SENT	bende isterim	2026-04-06 12:29:50.535229+03	2026-04-06 12:30:38.710696+03	FİLTRE KAHVELER	BAR
52	27	160	Tavuklu Krep	350.00	1.00	350.00	SENT	\N	2026-04-06 12:34:58.391278+03	2026-04-06 12:34:58.421018+03	KREPLER	MUTFAK
154	42	536	Çay	40.00	7.00	280.00	SENT	açık\nkoyu 1	2026-04-06 21:55:39.559269+03	2026-04-06 21:55:39.58206+03	ÇAYLAR	BAR
14	9	1252	Damla Sakızlı Türk Kahvesi	150.00	1.00	150.00	SENT	Orta Sekerli	2026-04-04 14:04:51.02564+03	2026-04-05 13:12:49.785019+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
16	9	1227	Adaçayı	160.00	1.00	160.00	SENT	\N	2026-04-04 18:11:15.757073+03	2026-04-04 18:37:05.040786+03	ÇAYLAR	BAR
17	9	1227	Adaçayı	160.00	1.00	160.00	SENT	\N	2026-04-04 18:11:23.073583+03	2026-04-04 18:37:05.040786+03	ÇAYLAR	BAR
20	9	1227	Adaçayı	160.00	2.00	320.00	SENT	\N	2026-04-04 18:37:04.99338+03	2026-04-04 18:37:05.040786+03	ÇAYLAR	BAR
15	9	1254	Dağ Çilekli Türk Kahvesi	150.00	1.00	150.00	SENT	Orta Sekerli	2026-04-04 14:04:51.02564+03	2026-04-04 18:37:31.33699+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
21	9	1163	Matcha	220.00	1.00	220.00	SENT	\N	2026-04-04 18:40:27.093058+03	2026-04-04 18:40:27.114282+03	MATCHA (MAÇA)	BAR
53	25	536	Çay	40.00	1.00	40.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
22	12	536	Çay	80.00	14.00	1120.00	SENT	\N	2026-04-04 18:42:10.880599+03	2026-04-04 18:42:21.788713+03	ÇAYLAR	BAR
54	25	1227	Adaçayı	160.00	1.00	160.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
55	25	1233	Limonlu Yeşil Çay	170.00	2.00	340.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
24	13	1254	Dağ Çilekli Türk Kahvesi	150.00	1.00	150.00	SENT	Cok Sekerli	2026-04-05 13:13:12.983458+03	2026-04-05 13:13:13.013319+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
25	13	1247	Osmanlı Dibek Kahvesi	150.00	1.00	150.00	SENT	Orta Sekerli	2026-04-05 13:13:12.983458+03	2026-04-05 13:13:13.013319+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
23	13	1252	Damla Sakızlı Türk Kahvesi	150.00	1.00	150.00	SENT	Cok Sekerli	2026-04-05 13:13:12.983458+03	2026-04-05 13:13:17.905809+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
56	25	537	Fincan Çay	70.00	2.00	140.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
26	14	1252	Damla Sakızlı Türk Kahvesi	150.00	1.00	150.00	SENT	Az Sekerli	2026-04-05 13:26:15.893859+03	2026-04-05 13:26:15.914276+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
57	25	1237	Kuşburnu Çayı	160.00	2.00	320.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
58	25	1238	Elma Çayı	160.00	1.00	160.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
27	12	1227	Adaçayı	160.00	2.00	320.00	SENT	\N	2026-04-05 13:28:32.080812+03	2026-04-05 13:28:32.09563+03	ÇAYLAR	BAR
28	12	1252	Damla Sakızlı Türk Kahvesi	150.00	2.00	300.00	SENT	Sade	2026-04-05 13:28:32.080812+03	2026-04-05 13:28:32.09563+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
29	12	1426	Affogato	220.00	1.00	220.00	SENT	\N	2026-04-05 13:29:27.842369+03	2026-04-05 13:29:27.85932+03	SOĞUK KAHVELER	BAR
30	12	537	Fincan Çay	70.00	1.00	70.00	SENT	\N	2026-04-05 13:29:41.046346+03	2026-04-05 13:29:41.058452+03	ÇAYLAR	BAR
32	12	1254	Dağ Çilekli Türk Kahvesi	150.00	2.00	300.00	SENT	Az Sekerli x1 | Sade x1	2026-04-05 13:35:26.022161+03	2026-04-05 13:35:26.064707+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
33	16	1236	Limonlu Siyah Çay	170.00	1.00	170.00	SENT	\N	2026-04-05 13:36:08.809551+03	2026-04-05 13:36:08.828671+03	ÇAYLAR	BAR
34	17	536	Çay	40.00	2.00	80.00	SENT	\N	2026-04-05 13:37:29.346779+03	2026-04-05 13:37:29.363173+03	ÇAYLAR	BAR
35	18	536	Çay	40.00	2.00	80.00	SENT	\N	2026-04-05 13:45:58.626823+03	2026-04-05 13:45:58.64061+03	ÇAYLAR	BAR
36	18	536	Çay	40.00	58.00	2320.00	SENT	\N	2026-04-05 13:47:19.990903+03	2026-04-05 13:47:20.044539+03	ÇAYLAR	BAR
37	8	536	Çay	40.00	2.00	80.00	SENT	\N	2026-04-05 13:54:15.930765+03	2026-04-05 13:54:15.945131+03	ÇAYLAR	BAR
31	15	1229	Ihlamur	200.00	2.00	400.00	SENT	\N	2026-04-05 13:29:56.180799+03	2026-04-05 14:29:15.490415+03	ÇAYLAR	BAR
41	20	1252	Damla Sakızlı Türk Kahvesi	150.00	2.00	300.00	SENT	Az Sekerli x1	2026-04-06 01:58:05.156872+03	2026-04-06 01:58:05.177848+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
87	35	1413	Damla Sakızlı Salep	200.00	1.00	200.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
88	35	1417	Bitter Sıcak Çikolata	200.00	2.00	400.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
89	35	1419	Beyaz Sıcak Çikolata	200.00	8.00	1600.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
90	35	1418	Dağ Çilekli Sıcak Çikolata	200.00	1.00	200.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
91	35	1412	Salep	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
59	25	1229	Ihlamur	160.00	1.00	160.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
60	25	1239	Böğürtlen Çayı	160.00	1.00	160.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
61	25	1236	Limonlu Siyah Çay	170.00	8.00	1360.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
62	25	1232	Nane - Limon Yeşil Çay	170.00	2.00	340.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
63	25	1242	Nane – Limon Çayı	160.00	3.00	480.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
64	25	1231	Naneli Yeşil Çay	170.00	1.00	170.00	SENT	\N	2026-04-06 12:36:29.467163+03	2026-04-06 12:36:29.50459+03	ÇAYLAR	BAR
93	35	1420	Aromalı Sıcak Çikolata	200.00	2.00	400.00	SENT	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	SAHLEP-SICAK ÇİKOLATA	BAR
65	29	536	Çay	40.00	1.00	40.00	SENT	\N	2026-04-06 12:42:24.935685+03	2026-04-06 12:42:24.976899+03	ÇAYLAR	BAR
66	29	1236	Limonlu Siyah Çay	170.00	1.00	170.00	SENT	\N	2026-04-06 12:42:24.935685+03	2026-04-06 12:42:24.976899+03	ÇAYLAR	BAR
67	29	1227	Adaçayı	160.00	1.00	160.00	SENT	\N	2026-04-06 12:42:24.935685+03	2026-04-06 12:42:24.976899+03	ÇAYLAR	BAR
125	35	1418	Dağ Çilekli Sıcak Çikolata	200.00	21.00	4200.00	SENT	\N	2026-04-06 12:47:45.016094+03	2026-04-06 12:47:45.035278+03	SAHLEP-SICAK ÇİKOLATA	BAR
126	35	1413	Damla Sakızlı Salep	200.00	15.00	3000.00	SENT	\N	2026-04-06 12:47:45.016094+03	2026-04-06 12:47:45.035278+03	SAHLEP-SICAK ÇİKOLATA	BAR
127	35	1417	Bitter Sıcak Çikolata	200.00	4.00	800.00	SENT	\N	2026-04-06 12:47:45.016094+03	2026-04-06 12:47:45.035278+03	SAHLEP-SICAK ÇİKOLATA	BAR
128	35	1419	Beyaz Sıcak Çikolata	200.00	3.00	600.00	SENT	\N	2026-04-06 12:47:45.016094+03	2026-04-06 12:47:45.035278+03	SAHLEP-SICAK ÇİKOLATA	BAR
68	30	1382	Çilek Milkshakes	250.00	7.00	1750.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
69	30	1386	Oreo Milkshakes	250.00	5.00	1250.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
70	30	1383	Muz Milkshakes	250.00	8.00	2000.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
71	30	694	Karadut Deryası Milkshakes	250.00	4.00	1000.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
72	30	1384	Karamel Milkshakes	250.00	4.00	1000.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
73	30	1385	Limon Milkshakes	250.00	5.00	1250.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
74	30	1381	Çikolata Milkshakes	250.00	7.00	1750.00	SENT	\N	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	MİLKSHAKELER	BAR
148	40	1252	Damla Sakızlı Türk Kahvesi	150.00	1.00	150.00	SENT	Sade x1	2026-04-06 19:43:04.85351+03	2026-04-06 19:43:04.862537+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
75	31	1382	Çilek Milkshakes	250.00	8.00	2000.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	MİLKSHAKELER	BAR
76	31	1381	Çikolata Milkshakes	250.00	6.00	1500.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	MİLKSHAKELER	BAR
77	31	1384	Karamel Milkshakes	250.00	1.00	250.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	MİLKSHAKELER	BAR
78	31	1385	Limon Milkshakes	250.00	2.00	500.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	MİLKSHAKELER	BAR
79	31	1383	Muz Milkshakes	250.00	1.00	250.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	MİLKSHAKELER	BAR
80	31	1254	Dağ Çilekli Türk Kahvesi	150.00	1.00	150.00	SENT	Az Sekerli x1	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
81	31	1247	Osmanlı Dibek Kahvesi	150.00	1.00	150.00	SENT	Orta Sekerli x1	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
82	31	1255	Double Aromalı Türk Kahvesi Çeşitleri	180.00	1.00	180.00	SENT	Cok Sekerli x1	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
83	31	1297	Guetemala Yirgacheffe	190.00	3.00	570.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	FİLTRE KAHVELER	BAR
84	31	1291	Sütlü Filtre Kahve	170.00	1.00	170.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	FİLTRE KAHVELER	BAR
85	31	1292	Karamelli Filtre Kahve	190.00	4.00	760.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	FİLTRE KAHVELER	BAR
86	31	1293	Fındıklı Filtre Kahve	190.00	1.00	190.00	SENT	\N	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	FİLTRE KAHVELER	BAR
104	35	1375	Çilekli Frozen	230.00	2.00	460.00	SENT	\N	2026-04-06 12:46:33.71814+03	2026-04-06 12:46:33.770693+03	MEYVELİ FROZENLER	BAR
105	35	1374	Tropicana Frozen	230.00	5.00	1150.00	SENT	\N	2026-04-06 12:46:33.71814+03	2026-04-06 12:46:33.770693+03	MEYVELİ FROZENLER	BAR
106	35	1377	Muzlu Frozen	230.00	1.00	230.00	SENT	\N	2026-04-06 12:46:33.71814+03	2026-04-06 12:46:33.770693+03	MEYVELİ FROZENLER	BAR
100	35	1299	White Mocha Frappe	250.00	2.00	500.00	SENT	\N	2026-04-06 12:46:28.762209+03	2026-04-06 12:47:26.733648+03	FRAPPELER	BAR
101	35	1298	Oreo Frappe	250.00	3.00	750.00	SENT	\N	2026-04-06 12:46:28.762209+03	2026-04-06 12:47:26.733648+03	FRAPPELER	BAR
102	35	1300	Dondurmalı Frappe	250.00	1.00	250.00	SENT	\N	2026-04-06 12:46:28.762209+03	2026-04-06 12:47:26.733648+03	FRAPPELER	BAR
103	35	1301	Kahve Deryası Frappe	250.00	2.00	500.00	SENT	\N	2026-04-06 12:46:28.762209+03	2026-04-06 12:47:26.733648+03	FRAPPELER	BAR
95	35	1417	Bitter Sıcak Çikolata	200.00	5.00	1000.00	SENT	\N	2026-04-06 12:46:25.554454+03	2026-04-06 12:47:29.417875+03	SAHLEP-SICAK ÇİKOLATA	BAR
96	35	1413	Damla Sakızlı Salep	200.00	8.00	1600.00	SENT	\N	2026-04-06 12:46:25.554454+03	2026-04-06 12:47:29.417875+03	SAHLEP-SICAK ÇİKOLATA	BAR
97	35	1415	Ballı - Bademli Salep	200.00	1.00	200.00	SENT	\N	2026-04-06 12:46:25.554454+03	2026-04-06 12:47:29.417875+03	SAHLEP-SICAK ÇİKOLATA	BAR
98	35	1416	Sıcak Çikolata	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:25.554454+03	2026-04-06 12:47:29.417875+03	SAHLEP-SICAK ÇİKOLATA	BAR
99	35	1414	Damla Sakızlı - Fındık Parçacıklı Salep	200.00	2.00	400.00	SENT	\N	2026-04-06 12:46:25.554454+03	2026-04-06 12:47:29.417875+03	SAHLEP-SICAK ÇİKOLATA	BAR
107	35	1376	Kavunlu Frozen	230.00	1.00	230.00	SENT	\N	2026-04-06 12:46:33.71814+03	2026-04-06 12:46:33.770693+03	MEYVELİ FROZENLER	BAR
108	35	1379	Nane Limon Frozen	230.00	1.00	230.00	SENT	\N	2026-04-06 12:46:33.71814+03	2026-04-06 12:46:33.770693+03	MEYVELİ FROZENLER	BAR
109	35	1378	Şeftali Frozen	230.00	2.00	460.00	SENT	\N	2026-04-06 12:46:33.71814+03	2026-04-06 12:46:33.770693+03	MEYVELİ FROZENLER	BAR
110	35	1417	Bitter Sıcak Çikolata	200.00	3.00	600.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
111	35	1419	Beyaz Sıcak Çikolata	200.00	5.00	1000.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
112	35	1415	Ballı - Bademli Salep	200.00	2.00	400.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
113	35	1420	Aromalı Sıcak Çikolata	200.00	6.00	1200.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
114	35	1413	Damla Sakızlı Salep	200.00	8.00	1600.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
115	35	1414	Damla Sakızlı - Fındık Parçacıklı Salep	200.00	1.00	200.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
116	35	1412	Salep	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
117	35	1418	Dağ Çilekli Sıcak Çikolata	200.00	2.00	400.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
118	35	1416	Sıcak Çikolata	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	SAHLEP-SICAK ÇİKOLATA	BAR
129	35	1303	Leb-i Derya Kahvaltı (Yöresel Kahvaltı)	800.00	49.00	39200.00	SENT	\N	2026-04-06 12:47:59.243015+03	2026-04-06 12:47:59.278651+03	KAHVALTI VE BAŞLANGIÇLAR	MUTFAK
131	38	1418	Dağ Çilekli Sıcak Çikolata	200.00	1.00	200.00	SENT	\N	2026-04-06 12:48:33.2599+03	2026-04-06 12:48:33.288567+03	SAHLEP-SICAK ÇİKOLATA	BAR
133	38	1417	Bitter Sıcak Çikolata	200.00	1.00	200.00	SENT	\N	2026-04-06 12:48:33.2599+03	2026-04-06 12:48:33.288567+03	SAHLEP-SICAK ÇİKOLATA	BAR
119	35	482	Beyaz Çikolatalı Smoothie	250.00	1.00	250.00	SENT	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	SOĞUK İÇECEKLER	BAR
120	35	1186	Bubble Tea Limon	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	SOĞUK İÇECEKLER	BAR
121	35	1187	Bubble Tea Frenk	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	SOĞUK İÇECEKLER	BAR
122	35	1168	Buzlu Beyaz Çikolata	160.00	4.00	640.00	SENT	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	SOĞUK İÇECEKLER	BAR
123	35	1188	Bubble Tea Çilek	190.00	3.00	570.00	SENT	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	SOĞUK İÇECEKLER	BAR
124	35	1185	Bubble Tea Çarkıfelek	190.00	1.00	190.00	SENT	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	SOĞUK İÇECEKLER	BAR
134	38	1414	Damla Sakızlı - Fındık Parçacıklı Salep	200.00	1.00	200.00	SENT	\N	2026-04-06 12:48:33.2599+03	2026-04-06 12:48:33.288567+03	SAHLEP-SICAK ÇİKOLATA	BAR
135	38	1416	Sıcak Çikolata	190.00	1.00	190.00	SENT	\N	2026-04-06 12:48:33.2599+03	2026-04-06 12:48:33.288567+03	SAHLEP-SICAK ÇİKOLATA	BAR
136	39	1227	Adaçayı	160.00	1.00	160.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
137	39	1229	Ihlamur	160.00	5.00	800.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
138	39	1238	Elma Çayı	160.00	1.00	160.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
140	39	1233	Limonlu Yeşil Çay	170.00	1.00	170.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
141	39	1237	Kuşburnu Çayı	160.00	3.00	480.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
142	39	537	Fincan Çay	70.00	1.00	70.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
143	39	1236	Limonlu Siyah Çay	170.00	2.00	340.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
144	39	536	Çay	40.00	1.00	40.00	SENT	\N	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	ÇAYLAR	BAR
132	38	1413	Damla Sakızlı Salep	200.00	1.00	200.00	SENT	\N	2026-04-06 12:48:33.2599+03	2026-04-06 13:19:53.856258+03	SAHLEP-SICAK ÇİKOLATA	BAR
130	38	1420	Aromalı Sıcak Çikolata	200.00	1.00	200.00	SENT	\N	2026-04-06 12:48:33.2599+03	2026-04-06 13:20:04.583833+03	SAHLEP-SICAK ÇİKOLATA	BAR
149	41	536	Çay	50.00	3.00	150.00	SENT	açık	2026-04-06 20:31:01.501958+03	2026-04-06 20:32:29.037124+03	ÇAYLAR	BAR
153	42	1252	Damla Sakızlı Türk Kahvesi	150.00	3.00	450.00	SENT	Sade 1\nAz Sekerli 2	2026-04-06 21:54:34.760214+03	2026-04-06 21:54:34.833078+03	TÜRK KAHVESİ ÇEŞİTLERİ	BAR
155	42	536	Çay	40.00	1.00	40.00	SENT	demli 1	2026-04-06 21:56:19.199724+03	2026-04-06 21:56:19.252722+03	ÇAYLAR	BAR
156	42	536	Çay	40.00	2.00	80.00	SENT	demli 2	2026-04-06 21:58:57.902782+03	2026-04-06 21:58:57.925704+03	ÇAYLAR	BAR
157	42	536	Çay	40.00	1.00	40.00	SENT	demli 1	2026-04-06 21:59:57.705423+03	2026-04-06 21:59:57.727734+03	ÇAYLAR	BAR
158	40	176	Beşamel Soslu Tavuk	350.00	2.00	700.00	SENT	az pişmiş\nbu da orta pıskın 1	2026-04-06 22:01:29.846467+03	2026-04-06 22:01:29.86101+03	ANA YEMEKLER	MUTFAK
159	40	181	Bodrum Çökertmesi	600.00	1.00	600.00	SENT	cok pısmıs	2026-04-06 22:01:29.846467+03	2026-04-06 22:01:29.86101+03	ANA YEMEKLER	MUTFAK
160	40	176	Beşamel Soslu Tavuk	350.00	1.00	350.00	SENT	pişkin 1	2026-04-06 22:03:20.465516+03	2026-04-06 22:03:20.496596+03	ANA YEMEKLER	MUTFAK
161	40	536	Çay	40.00	1.00	40.00	SENT	sa acık	2026-04-06 22:36:23.301986+03	2026-04-06 22:36:23.361125+03	ÇAYLAR	BAR
162	40	176	Beşamel Soslu Tavuk	350.00	1.00	350.00	SENT	az pişmiş\nbu da orta pıskın 1 | pişkin 1 1	2026-04-06 22:36:49.493708+03	2026-04-06 22:36:49.513727+03	ANA YEMEKLER	MUTFAK
163	40	181	Bodrum Çökertmesi	600.00	1.00	600.00	SENT	cok pısmıs 1	2026-04-06 22:36:49.493708+03	2026-04-06 22:36:49.513727+03	ANA YEMEKLER	MUTFAK
164	40	176	Beşamel Soslu Tavuk	350.00	1.00	350.00	SENT	az pişmiş\nbu da orta pıskın 1 | az pişmiş\nbu da orta pıskın 1 | pişkin 1 1 | pişkin 1	2026-04-06 22:44:56.21128+03	2026-04-06 22:44:56.243608+03	ANA YEMEKLER	MUTFAK
165	40	176	Beşamel Soslu Tavuk	350.00	1.00	350.00	SENT	az pişmiş\nbu da orta pıskın 1 | az pişmiş\nbu da orta pıskın 1 | az pişmiş\nbu da orta pıskın 1 | pişkin 1 1 | pişkin 1 | az pişmiş\nbu da orta pıskın 1 | pişkin 1 1 | pişkin 1 1	2026-04-06 22:50:58.591914+03	2026-04-06 22:50:58.651915+03	ANA YEMEKLER	MUTFAK
166	40	536	Çay	40.00	1.00	40.00	SENT	sa acık	2026-04-06 22:52:14.724748+03	2026-04-06 22:52:14.740848+03	ÇAYLAR	BAR
167	43	1426	Affogato	220.00	1.00	220.00	SENT	\N	2026-04-06 22:52:53.984738+03	2026-04-06 22:52:54.005606+03	SOĞUK KAHVELER	BAR
168	43	1431	Frappe	250.00	1.00	250.00	SENT	\N	2026-04-06 22:52:53.984738+03	2026-04-06 22:52:54.005606+03	SOĞUK KAHVELER	BAR
169	43	1433	Ice Americano	170.00	1.00	170.00	SENT	\N	2026-04-06 22:52:53.984738+03	2026-04-06 22:52:54.005606+03	SOĞUK KAHVELER	BAR
170	43	1382	Çilek Milkshakes	250.00	1.00	250.00	SENT	\N	2026-04-06 22:53:31.565308+03	2026-04-06 22:53:31.575897+03	MİLKSHAKELER	BAR
171	43	1381	Çikolata Milkshakes	250.00	2.00	500.00	SENT	\N	2026-04-06 22:53:51.634124+03	2026-04-06 22:53:51.648393+03	MİLKSHAKELER	BAR
172	43	1298	Oreo Frappe	250.00	1.00	250.00	SENT	\N	2026-04-06 23:00:22.477738+03	2026-04-06 23:00:22.533267+03	FRAPPELER	BAR
173	43	150	Big Chicken	280.00	1.00	280.00	SENT	\N	2026-04-06 23:00:31.202371+03	2026-04-06 23:00:31.239473+03	HAMBURGERLER	MUTFAK
174	43	148	Cheese Burger	350.00	1.00	350.00	SENT	\N	2026-04-06 23:00:31.202371+03	2026-04-06 23:00:31.239473+03	HAMBURGERLER	MUTFAK
175	43	181	Bodrum Çökertmesi	600.00	2.00	1200.00	SENT	\N	2026-04-06 23:00:53.316105+03	2026-04-06 23:00:53.343209+03	ANA YEMEKLER	MUTFAK
176	43	1382	Çilek Milkshakes	250.00	1.00	250.00	SENT	\N	2026-04-06 23:02:01.191111+03	2026-04-06 23:02:01.213624+03	MİLKSHAKELER	BAR
177	43	1169	Çikolatalı Smoothie	250.00	1.00	250.00	SENT	\N	2026-04-06 23:02:15.806819+03	2026-04-06 23:02:15.841237+03	SOĞUK İÇECEKLER	BAR
178	43	1383	Muz Milkshakes	250.00	1.00	250.00	SENT	meehaba	2026-04-06 23:02:55.334267+03	2026-04-06 23:02:55.362702+03	MİLKSHAKELER	BAR
179	43	1299	White Mocha Frappe	250.00	1.00	250.00	SENT	\N	2026-04-06 23:03:27.064577+03	2026-04-06 23:03:27.1196+03	FRAPPELER	BAR
180	40	1236	Limonlu Siyah Çay	170.00	5.00	850.00	SENT	\N	2026-04-06 23:48:42.861486+03	2026-04-06 23:48:42.915449+03	ÇAYLAR	BAR
\.


--
-- Data for Name: orders; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.orders (id, table_id, waiter_id, opened_by_user_id, closed_by_user_id, order_status, note, subtotal, discount_total, grand_total, opened_at, confirmed_at, closed_at, created_at, updated_at, payment_method, guest_count, table_note, payment_lock_user_id, payment_lock_at) FROM stdin;
19	122	3	3	3	PAID	\N	120.00	0.00	120.00	2026-04-06 01:25:19.011916+03	2026-04-06 01:25:19.071315+03	2026-04-06 12:23:04.466885+03	2026-04-06 01:25:19.011916+03	2026-04-06 12:23:04.466885+03	\N	1	\N	\N	\N
20	123	3	3	3	PAID	\N	300.00	0.00	300.00	2026-04-06 01:58:05.156872+03	2026-04-06 01:58:05.177848+03	2026-04-06 02:09:43.015178+03	2026-04-06 01:58:05.156872+03	2026-04-06 02:09:43.015178+03	\N	1	\N	\N	\N
1	122	3	3	3	PAID	\N	190.00	0.00	190.00	2026-04-01 00:34:59.621133+03	2026-04-01 00:34:59.639427+03	2026-04-01 00:35:18.132576+03	2026-04-01 00:34:59.621133+03	2026-04-01 00:35:18.132576+03	CASH	1	\N	\N	\N
12	142	3	3	3	PAID	\N	2330.00	0.00	2330.00	2026-04-04 18:42:10.880599+03	2026-04-05 13:35:26.064707+03	2026-04-05 13:35:38.537123+03	2026-04-04 18:42:10.880599+03	2026-04-05 13:35:38.537123+03	\N	1	\N	\N	\N
38	132	1	1	3	PAID	\N	1291.00	0.00	1291.00	2026-04-06 12:48:33.2599+03	2026-04-06 13:19:48.975971+03	2026-04-06 13:35:39.927938+03	2026-04-06 12:48:33.2599+03	2026-04-06 13:35:39.927938+03	\N	1	\N	\N	\N
30	132	1	1	3	PAID	\N	10000.00	0.00	10000.00	2026-04-06 12:42:44.042584+03	2026-04-06 12:42:44.064142+03	2026-04-06 12:43:25.605868+03	2026-04-06 12:42:44.042584+03	2026-04-06 12:43:25.605868+03	\N	1	\N	\N	\N
2	122	3	3	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-01 00:35:26.839675+03	2026-04-01 00:35:26.856425+03	\N	2026-04-01 00:35:26.839675+03	2026-04-01 12:26:02.982624+03	\N	1	\N	\N	\N
40	122	3	3	\N	CONFIRMED	\N	4380.00	0.00	4380.00	2026-04-06 19:41:45.802114+03	2026-04-06 23:48:42.915449+03	\N	2026-04-06 19:41:45.802114+03	2026-04-06 23:48:42.915449+03	\N	1	\N	\N	\N
10	127	3	3	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-04 14:01:15.911186+03	2026-04-05 14:14:24.012637+03	\N	2026-04-04 14:01:15.911186+03	2026-04-05 14:24:24.428169+03	\N	1	\N	\N	\N
3	122	3	3	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-01 12:30:19.433579+03	2026-04-01 12:30:19.457539+03	\N	2026-04-01 12:30:19.433579+03	2026-04-01 12:30:29.855332+03	\N	1	\N	\N	\N
22	124	3	3	3	PAID	\N	890.00	0.00	890.00	2026-04-06 02:09:08.63318+03	2026-04-06 02:09:08.702327+03	2026-04-06 02:09:56.610077+03	2026-04-06 02:09:08.63318+03	2026-04-06 02:09:56.610077+03	\N	1	\N	\N	\N
17	122	1	1	3	PAID	\N	80.00	0.00	80.00	2026-04-05 13:37:29.346779+03	2026-04-05 13:37:29.363173+03	2026-04-05 13:43:23.285573+03	2026-04-05 13:37:29.346779+03	2026-04-05 13:43:23.285573+03	\N	1	\N	\N	\N
16	142	1	1	3	PAID	\N	170.00	0.00	170.00	2026-04-05 13:36:08.809551+03	2026-04-05 13:36:08.828671+03	2026-04-05 13:43:55.362598+03	2026-04-05 13:36:08.809551+03	2026-04-05 13:43:55.362598+03	\N	1	\N	\N	\N
41	123	3	3	3	PAID	\N	200.00	0.00	200.00	2026-04-06 20:31:01.501958+03	2026-04-06 20:31:28.521387+03	2026-04-06 20:32:35.100019+03	2026-04-06 20:31:01.501958+03	2026-04-06 20:32:35.100019+03	\N	1	\N	\N	\N
15	135	1	1	3	PAID	\N	400.00	0.00	400.00	2026-04-05 13:29:56.180799+03	2026-04-05 13:29:56.194194+03	2026-04-05 14:29:24.371806+03	2026-04-05 13:29:56.180799+03	2026-04-05 14:29:24.371806+03	\N	1	\N	\N	\N
27	124	3	3	3	PAID	\N	500.00	0.00	500.00	2026-04-06 12:29:19.750838+03	2026-04-06 12:34:58.421018+03	2026-04-06 12:35:11.753568+03	2026-04-06 12:29:19.750838+03	2026-04-06 12:35:11.753568+03	\N	1	\N	\N	\N
5	123	3	3	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-01 12:32:11.131449+03	2026-04-01 12:32:11.149823+03	\N	2026-04-01 12:32:11.131449+03	2026-04-01 12:32:22.369993+03	\N	1	\N	\N	\N
11	128	3	3	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-04 18:20:53.930535+03	2026-04-04 18:20:53.964395+03	\N	2026-04-04 18:20:53.930535+03	2026-04-04 18:41:32.973723+03	\N	1	\N	\N	\N
4	122	3	3	3	PAID	\N	700.00	0.00	700.00	2026-04-01 12:31:07.552887+03	2026-04-01 12:31:45.570467+03	2026-04-01 12:33:41.098409+03	2026-04-01 12:31:07.552887+03	2026-04-01 12:33:41.098409+03	CASH	1	\N	\N	\N
18	122	3	3	3	PAID	\N	2400.00	0.00	2400.00	2026-04-05 13:45:58.626823+03	2026-04-05 13:47:20.044539+03	2026-04-05 13:47:28.001412+03	2026-04-05 13:45:58.626823+03	2026-04-05 13:47:28.001412+03	\N	1	\N	\N	\N
43	127	3	3	3	PAID	\N	4470.00	0.00	4470.00	2026-04-06 22:52:53.984738+03	2026-04-06 23:03:27.1196+03	2026-04-06 23:06:39.09631+03	2026-04-06 22:52:53.984738+03	2026-04-06 23:06:39.09631+03	\N	1	\N	\N	\N
6	122	3	3	3	PAID	\N	570.00	70.00	500.00	2026-04-01 12:33:52.000242+03	2026-04-01 12:33:52.01476+03	2026-04-01 12:34:13.027052+03	2026-04-01 12:33:52.000242+03	2026-04-01 12:34:13.027052+03	MIXED	1	\N	\N	\N
42	123	3	3	3	PAID	\N	890.00	0.00	890.00	2026-04-06 21:54:34.760214+03	2026-04-06 21:59:57.727734+03	2026-04-06 23:11:22.569537+03	2026-04-06 21:54:34.760214+03	2026-04-06 23:11:22.569537+03	\N	1	\N	\N	\N
13	130	3	3	3	PAID	\N	450.00	0.00	450.00	2026-04-05 13:13:12.983458+03	2026-04-05 13:13:13.013319+03	2026-04-05 13:55:03.350645+03	2026-04-05 13:13:12.983458+03	2026-04-05 13:55:03.350645+03	\N	1	\N	\N	\N
7	122	3	3	3	PAID	\N	1.00	0.00	1.00	2026-04-01 12:35:29.450091+03	2026-04-01 12:35:29.462098+03	2026-04-04 13:25:06.021476+03	2026-04-01 12:35:29.450091+03	2026-04-04 13:25:06.021476+03	CASH	1	\N	\N	\N
21	126	3	3	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-06 02:05:33.736851+03	2026-04-06 02:05:33.767138+03	\N	2026-04-06 02:05:33.736851+03	2026-04-06 02:07:31.413574+03	\N	1	\N	\N	\N
8	123	3	3	3	PAID	\N	1270.00	0.00	1270.00	2026-04-01 12:36:14.677671+03	2026-04-05 13:54:15.945131+03	2026-04-05 14:12:49.070783+03	2026-04-01 12:36:14.677671+03	2026-04-05 14:12:49.070783+03	\N	1	\N	\N	\N
25	125	1	1	3	PAID	\N	3980.00	0.00	3980.00	2026-04-06 12:20:05.426652+03	2026-04-06 12:36:29.50459+03	2026-04-06 12:42:15.841774+03	2026-04-06 12:20:05.426652+03	2026-04-06 12:42:15.841774+03	\N	1	\N	\N	\N
28	126	3	3	3	PAID	\N	190.00	0.00	190.00	2026-04-06 12:29:50.535229+03	2026-04-06 12:29:50.579928+03	2026-04-06 12:34:07.42561+03	2026-04-06 12:29:50.535229+03	2026-04-06 12:34:07.42561+03	\N	1	\N	\N	\N
9	122	3	3	3	PAID	\N	1540.00	0.00	1540.00	2026-04-04 13:33:30.185829+03	2026-04-04 18:40:27.114282+03	2026-04-05 13:26:36.020177+03	2026-04-04 13:33:30.185829+03	2026-04-05 13:26:36.020177+03	\N	1	\N	\N	\N
26	122	1	1	3	PAID	\N	300.00	0.00	300.00	2026-04-06 12:23:41.676925+03	2026-04-06 12:23:41.695131+03	2026-04-06 12:34:16.062553+03	2026-04-06 12:23:41.676925+03	2026-04-06 12:34:16.062553+03	\N	1	\N	\N	\N
24	124	3	3	3	PAID	\N	180.00	0.00	180.00	2026-04-06 12:13:52.197964+03	2026-04-06 12:13:52.257993+03	2026-04-06 12:14:24.767431+03	2026-04-06 12:13:52.197964+03	2026-04-06 12:14:24.767431+03	\N	1	\N	\N	\N
29	122	3	3	3	PAID	\N	370.00	0.00	370.00	2026-04-06 12:42:24.935685+03	2026-04-06 12:42:24.976899+03	2026-04-06 12:42:38.652747+03	2026-04-06 12:42:24.935685+03	2026-04-06 12:42:38.652747+03	\N	1	\N	\N	\N
23	123	1	1	3	PAID	\N	80.00	0.00	80.00	2026-04-06 02:12:52.718483+03	2026-04-06 02:12:52.753411+03	2026-04-06 12:34:27.344501+03	2026-04-06 02:12:52.718483+03	2026-04-06 12:34:27.344501+03	\N	1	\N	\N	\N
14	125	1	1	3	PAID	\N	150.00	0.00	150.00	2026-04-05 13:26:15.893859+03	2026-04-05 13:26:15.914276+03	2026-04-05 13:30:39.388557+03	2026-04-05 13:26:15.893859+03	2026-04-05 13:30:39.388557+03	\N	1	\N	\N	\N
37	128	1	1	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-06 12:46:45.821203+03	2026-04-06 12:46:45.840483+03	\N	2026-04-06 12:46:45.821203+03	2026-04-06 12:47:21.67799+03	\N	1	\N	\N	\N
34	127	1	1	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-06 12:46:28.762209+03	2026-04-06 12:46:28.785238+03	\N	2026-04-06 12:46:28.762209+03	2026-04-06 12:47:26.733648+03	\N	1	\N	\N	\N
39	122	1	1	3	PAID	\N	2220.00	0.00	2220.00	2026-04-06 12:48:39.949986+03	2026-04-06 12:48:40.099707+03	2026-04-06 12:59:42.135837+03	2026-04-06 12:48:39.949986+03	2026-04-06 12:59:42.135837+03	\N	1	\N	\N	\N
33	130	1	1	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-06 12:46:25.554454+03	2026-04-06 12:46:25.587135+03	\N	2026-04-06 12:46:25.554454+03	2026-04-06 12:47:29.417875+03	\N	1	\N	\N	\N
31	122	1	1	3	PAID	\N	6670.00	0.00	6670.00	2026-04-06 12:43:09.618392+03	2026-04-06 12:43:09.650067+03	2026-04-06 12:46:40.284641+03	2026-04-06 12:43:09.618392+03	2026-04-06 12:46:40.284641+03	\N	1	\N	\N	\N
36	132	1	1	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-06 12:46:41.500671+03	2026-04-06 12:46:41.521614+03	\N	2026-04-06 12:46:41.500671+03	2026-04-06 12:47:33.573368+03	\N	1	\N	\N	\N
32	141	1	1	\N	CANCELLED	\N	0.00	0.00	0.00	2026-04-06 12:46:20.942897+03	2026-04-06 12:46:21.011084+03	\N	2026-04-06 12:46:20.942897+03	2026-04-06 12:47:36.996728+03	\N	1	\N	\N	\N
35	129	1	1	3	PAID	\N	67330.00	60000.00	7330.00	2026-04-06 12:46:33.71814+03	2026-04-06 12:47:59.278651+03	2026-04-06 12:48:19.406777+03	2026-04-06 12:46:33.71814+03	2026-04-06 12:48:19.406777+03	\N	1	\N	\N	\N
\.


--
-- Data for Name: payments; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.payments (id, order_id, received_by_user_id, payment_method, amount, currency, payment_note, paid_at, created_at, discount_amount, updated_at) FROM stdin;
1	1	3	CASH	190.00	TRY	Kısmi ödeme	2026-04-01 00:35:18.132576+03	2026-04-01 00:35:18.132576+03	0.00	2026-04-06 23:16:13.126648+03
2	4	3	CASH	700.00	TRY	Kısmi ödeme	2026-04-01 12:33:41.098409+03	2026-04-01 12:33:41.098409+03	0.00	2026-04-06 23:16:13.126648+03
3	6	3	CARD	250.00	TRY	Kısmi ödeme	2026-04-01 12:34:13.027052+03	2026-04-01 12:34:13.027052+03	70.00	2026-04-06 23:16:13.126648+03
4	6	3	CASH	250.00	TRY	Kısmi ödeme	2026-04-01 12:34:13.027052+03	2026-04-01 12:34:13.027052+03	0.00	2026-04-06 23:16:13.126648+03
5	7	3	CASH	1.00	TRY	Kısmi ödeme	2026-04-04 13:25:06.021476+03	2026-04-04 13:25:06.021476+03	0.00	2026-04-06 23:16:13.126648+03
6	9	3	CASH	1540.00	TRY	Tutar girerek odeme	2026-04-05 13:26:36.020177+03	2026-04-05 13:26:36.020177+03	0.00	2026-04-06 23:16:13.126648+03
7	14	3	CASH	150.00	TRY	Tutar girerek odeme	2026-04-05 13:30:39.388557+03	2026-04-05 13:30:39.388557+03	0.00	2026-04-06 23:16:13.126648+03
8	12	3	CASH	2330.00	TRY	Tutar girerek odeme	2026-04-05 13:35:38.537123+03	2026-04-05 13:35:38.537123+03	0.00	2026-04-06 23:16:13.126648+03
9	17	3	CASH	80.00	TRY	Tutar girerek odeme	2026-04-05 13:43:23.285573+03	2026-04-05 13:43:23.285573+03	0.00	2026-04-06 23:16:13.126648+03
10	16	3	CASH	170.00	TRY	Tutar girerek odeme	2026-04-05 13:43:55.362598+03	2026-04-05 13:43:55.362598+03	0.00	2026-04-06 23:16:13.126648+03
11	18	3	CASH	2400.00	TRY	Tutar girerek odeme	2026-04-05 13:47:28.001412+03	2026-04-05 13:47:28.001412+03	0.00	2026-04-06 23:16:13.126648+03
12	13	3	CASH	450.00	TRY	Tutar girerek odeme	2026-04-05 13:55:03.350645+03	2026-04-05 13:55:03.350645+03	0.00	2026-04-06 23:16:13.126648+03
13	8	3	CASH	1270.00	TRY	Tutar girerek odeme	2026-04-05 14:12:49.070783+03	2026-04-05 14:12:49.070783+03	0.00	2026-04-06 23:16:13.126648+03
14	15	3	CASH	400.00	TRY	Tutar girerek odeme	2026-04-05 14:29:24.371806+03	2026-04-05 14:29:24.371806+03	0.00	2026-04-06 23:16:13.126648+03
15	20	3	CASH	300.00	TRY	Tutar girerek odeme	2026-04-06 02:09:43.015178+03	2026-04-06 02:09:43.015178+03	0.00	2026-04-06 23:16:13.126648+03
16	22	3	CARD	290.00	TRY	Tutar girerek odeme	2026-04-06 02:09:56.581926+03	2026-04-06 02:09:56.581926+03	0.00	2026-04-06 23:16:13.126648+03
17	22	3	CASH	600.00	TRY	Tutar girerek odeme	2026-04-06 02:09:56.610077+03	2026-04-06 02:09:56.610077+03	0.00	2026-04-06 23:16:13.126648+03
18	24	3	CASH	180.00	TRY	Tutar girerek odeme	2026-04-06 12:14:24.767431+03	2026-04-06 12:14:24.767431+03	0.00	2026-04-06 23:16:13.126648+03
19	19	3	CASH	120.00	TRY	Tutar girerek odeme	2026-04-06 12:23:04.466885+03	2026-04-06 12:23:04.466885+03	0.00	2026-04-06 23:16:13.126648+03
20	28	3	CASH	190.00	TRY	Tutar girerek odeme	2026-04-06 12:34:07.42561+03	2026-04-06 12:34:07.42561+03	0.00	2026-04-06 23:16:13.126648+03
21	26	3	CARD	300.00	TRY	Tutar girerek odeme	2026-04-06 12:34:16.062553+03	2026-04-06 12:34:16.062553+03	0.00	2026-04-06 23:16:13.126648+03
22	23	3	CASH	40.00	TRY	Tutar girerek odeme	2026-04-06 12:34:27.333342+03	2026-04-06 12:34:27.333342+03	0.00	2026-04-06 23:16:13.126648+03
23	23	3	CARD	40.00	TRY	Tutar girerek odeme	2026-04-06 12:34:27.344501+03	2026-04-06 12:34:27.344501+03	0.00	2026-04-06 23:16:13.126648+03
24	27	3	CASH	500.00	TRY	Tutar girerek odeme	2026-04-06 12:35:11.753568+03	2026-04-06 12:35:11.753568+03	0.00	2026-04-06 23:16:13.126648+03
25	25	3	CASH	3980.00	TRY	Tutar girerek odeme	2026-04-06 12:42:15.841774+03	2026-04-06 12:42:15.841774+03	0.00	2026-04-06 23:16:13.126648+03
26	29	3	CARD	370.00	TRY	Tutar girerek odeme	2026-04-06 12:42:38.652747+03	2026-04-06 12:42:38.652747+03	0.00	2026-04-06 23:16:13.126648+03
27	30	3	CASH	10000.00	TRY	Tutar girerek odeme	2026-04-06 12:43:25.605868+03	2026-04-06 12:43:25.605868+03	0.00	2026-04-06 23:16:13.126648+03
28	31	3	CASH	6670.00	TRY	Tutar girerek odeme	2026-04-06 12:46:40.284641+03	2026-04-06 12:46:40.284641+03	0.00	2026-04-06 23:16:13.126648+03
29	35	3	CASH	7330.00	TRY	Tutar girerek odeme	2026-04-06 12:48:19.406777+03	2026-04-06 12:48:19.406777+03	0.00	2026-04-06 23:16:13.126648+03
30	39	3	CASH	2220.00	TRY	Tutar girerek odeme	2026-04-06 12:59:42.135837+03	2026-04-06 12:59:42.135837+03	0.00	2026-04-06 23:16:13.126648+03
31	38	3	CASH	1291.00	TRY	Tutar girerek odeme	2026-04-06 13:35:39.927938+03	2026-04-06 13:35:39.927938+03	0.00	2026-04-06 23:16:13.126648+03
32	41	3	CASH	200.00	TRY	Tutar girerek odeme	2026-04-06 20:32:35.100019+03	2026-04-06 20:32:35.100019+03	0.00	2026-04-06 23:16:13.126648+03
33	43	3	CASH	1270.00	TRY	Tutar girerek odeme	2026-04-06 23:06:39.051785+03	2026-04-06 23:06:39.051785+03	0.00	2026-04-06 23:16:13.126648+03
34	43	3	CARD	500.00	TRY	Tutar girerek odeme	2026-04-06 23:06:39.073879+03	2026-04-06 23:06:39.073879+03	0.00	2026-04-06 23:16:13.126648+03
35	43	3	CASH	2700.00	TRY	Tutar girerek odeme	2026-04-06 23:06:39.09631+03	2026-04-06 23:06:39.09631+03	0.00	2026-04-06 23:16:13.126648+03
36	42	3	CASH	890.00	TRY	Tutar girerek odeme	2026-04-06 23:11:22.569537+03	2026-04-06 23:11:22.569537+03	0.00	2026-04-06 23:16:13.126648+03
\.


--
-- Data for Name: products; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.products (id, category_id, name, sku, price, vat_rate, is_active, created_at, updated_at, category, image_url) FROM stdin;
1120	106	Capris	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1121	106	Dejavu	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
507	25	Big Chicken	\N	280.00	10.00	f	2026-03-28 16:16:36.497667+03	2026-03-30 21:47:06.496189+03	ANA YEMEKLER	\N
55	23	Sıcak Çikolata	SIC-004	65.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-04-06 23:16:42.958266+03	SICAK İÇECEKLER	\N
58	23	Çay	SIC-001	15.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-04-06 23:16:42.958266+03	SICAK İÇECEKLER	\N
1266	86	Cappucino	\N	400.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:22:45.644366+03	ESPRESSOLU KAHVELER	\N
1139	107	Matcha Coco Cloud	\N	220.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	MATCHA (MAÇA)	\N
1140	107	Matcha Passion Fruit	\N	220.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	MATCHA (MAÇA)	\N
1141	107	Matcha Pink	\N	220.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	MATCHA (MAÇA)	\N
1119	96	Ballı Cevizli Marlenka	\N	250.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:39:09.87918+03	PASTA VE KEKLER	\N
1122	96	Deli Fıstık	\N	300.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:39:50.824528+03	PASTA VE KEKLER	\N
1123	96	Dubai Cup	\N	250.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:40:20.087214+03	PASTA VE KEKLER	\N
1155	96	Sütlaç	\N	150.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:40:53.268931+03	PASTA VE KEKLER	\N
1144	96	Mono Frambuazlı Kalp	\N	300.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:43:20.102604+03	PASTA VE KEKLER	\N
57	23	Fincan Çay	SIC-002	25.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-04-06 23:16:42.958266+03	SICAK İÇECEKLER	\N
114	30	Leb-i Derya Kahvaltı	\N	800.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 20:41:09.623366+03	KAHVALTI VE BAŞLANGIÇLAR	\N
59	24	Şalgam	SGK-004	30.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-03-30 20:52:50.058215+03	SOĞUK İÇECEKLER	\N
60	24	Su	SGK-003	10.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-03-30 20:52:50.058215+03	SOĞUK İÇECEKLER	\N
138	31	Parmak Patates Ve Soğan Halkası	\N	220.00	10.00	t	2026-03-27 19:11:59.295518+03	2026-03-30 20:41:09.623366+03	APERATİFLER	\N
66	25	Izgara Köfte	ANA-001	250.00	10.00	t	2026-03-22 18:28:23.448475+03	2026-03-30 20:41:09.623366+03	ANA YEMEKLER	\N
67	26	Karışık Dondurma	DON-001	90.00	10.00	t	2026-03-22 18:28:23.448475+03	2026-03-30 20:41:09.623366+03	DONDURMALAR	\N
61	24	Ayran	SGK-002	25.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-03-30 20:52:50.058215+03	SOĞUK İÇECEKLER	\N
62	24	Kola	SGK-001	40.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-03-30 20:52:50.058215+03	SOĞUK İÇECEKLER	\N
63	25	Adana Kebap	ANA-004	280.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-03-30 21:45:59.582403+03	ANA YEMEKLER	\N
64	25	Hamburger Menü	ANA-003	200.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-03-30 21:46:45.622209+03	ANA YEMEKLER	\N
142	32	Ton Balıklı Sandviç	\N	300.00	10.00	t	2026-03-27 19:13:37.246886+03	2026-03-30 20:41:09.623366+03	SANDVİÇLER VE TOSTLAR	\N
143	32	Karışık Sandviç	\N	300.00	10.00	t	2026-03-27 19:13:37.246886+03	2026-03-30 20:41:09.623366+03	SANDVİÇLER VE TOSTLAR	\N
144	32	Philly Steak	\N	400.00	10.00	t	2026-03-27 19:13:37.246886+03	2026-03-30 20:41:09.623366+03	SANDVİÇLER VE TOSTLAR	\N
145	32	Club Sandviç	\N	320.00	10.00	t	2026-03-27 19:13:37.246886+03	2026-03-30 20:41:09.623366+03	SANDVİÇLER VE TOSTLAR	\N
148	33	Cheese Burger	\N	350.00	10.00	t	2026-03-27 19:14:33.862273+03	2026-03-30 17:46:56.153207+03	HAMBURGERLER	\N
149	33	Cheese Mushroom Burger	\N	520.00	10.00	t	2026-03-27 19:14:33.862273+03	2026-03-30 17:46:56.153207+03	HAMBURGERLER	\N
150	33	Big Chicken	\N	280.00	10.00	t	2026-03-27 19:14:33.862273+03	2026-03-30 17:46:56.153207+03	HAMBURGERLER	\N
151	33	Klasik Usul Burger	\N	320.00	10.00	t	2026-03-27 19:14:33.862273+03	2026-03-30 17:46:56.153207+03	HAMBURGERLER	\N
146	32	Kaşarlı Tost	\N	220.00	10.00	t	2026-03-27 19:13:37.246886+03	2026-03-30 20:41:09.623366+03	SANDVİÇLER VE TOSTLAR	\N
147	32	Karışık Tost	\N	260.00	10.00	t	2026-03-27 19:13:37.246886+03	2026-03-30 20:41:09.623366+03	SANDVİÇLER VE TOSTLAR	\N
153	34	Vejetaryen Pizza	\N	270.00	10.00	t	2026-03-27 19:17:04.931114+03	2026-03-30 20:41:09.623366+03	PİZZALAR	\N
157	35	Etli Wrap	\N	390.00	10.00	t	2026-03-27 19:17:45.146346+03	2026-03-30 20:41:09.623366+03	WRAPLER	\N
158	35	Tavuklu Wrap	\N	290.00	10.00	t	2026-03-27 19:17:45.146346+03	2026-03-30 20:41:09.623366+03	WRAPLER	\N
166	38	Penne Arrabbiata	\N	250.00	10.00	t	2026-03-27 19:22:20.93582+03	2026-03-30 20:41:09.623366+03	MAKARNALAR	\N
167	38	Penne Alfredo	\N	290.00	10.00	t	2026-03-27 19:22:20.93582+03	2026-03-30 20:41:09.623366+03	MAKARNALAR	\N
170	38	Fettuccine Alfredo	\N	320.00	10.00	t	2026-03-27 19:22:20.93582+03	2026-03-30 20:41:09.623366+03	MAKARNALAR	\N
187	41	Gevrek Kahvaltı Soğuk	\N	230.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
188	41	Gevrek Kahvaltı Sıcak	\N	250.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
189	41	Kahvaltı Tabağı	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
190	41	Sahanda Yumurta	\N	120.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
191	41	Ekmek Üstü	\N	450.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
192	41	Pişi Kahvaltı	\N	450.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
194	41	Sahanda Sucuklu Yumurta	\N	160.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
195	41	Bal Kaymak	\N	160.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
196	41	Peynir Tabağı	\N	220.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Kahvaltısız Yapamayanlar	\N
197	42	Sade Omlet	\N	150.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Omlet	\N
198	42	Beyaz Peynirli Omlet	\N	170.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Omlet	\N
199	42	Kaşarlı Omlet	\N	175.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Omlet	\N
200	42	Sucuklu Omlet	\N	180.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Omlet	\N
201	42	Omlet Deryası	\N	220.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Omlet	\N
224	48	Karışık Pizza	\N	370.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Pizzalar	\N
225	48	Ton Balıklı Pizza	\N	370.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Pizzalar	\N
227	48	Pastırmalı Pizza	\N	400.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Pizzalar	\N
228	48	Margarita Pizza	\N	270.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Pizzalar	\N
229	49	Etli Wrap	\N	390.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Wrapler	\N
230	49	Tavuklu Wrap	\N	290.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Wrapler	\N
231	50	Etli Krep	\N	450.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Krepler	\N
232	50	Tavuklu Krep	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Krepler	\N
233	51	Ege Usulü	\N	270.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Salatalar	\N
234	51	Diyet Salata	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Salatalar	\N
235	51	Hellim Salata	\N	280.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Salatalar	\N
236	51	Ton Balıklı Salata	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Salatalar	\N
237	51	Tavuklu Sezar Salata	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Salatalar	\N
239	52	Mantı	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Makarnalar	\N
242	52	Spagetti Napoliten	\N	250.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Makarnalar	\N
243	52	Spagetti Bolognese	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Makarnalar	\N
244	53	Beşamel Soslu Tavuk	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
1458	24	deneemee	\N	100.00	10.00	t	2026-03-30 21:48:56.263017+03	2026-03-30 21:48:56.263017+03	SOĞUK İÇECEKLER	\N
983	26	Dondurmalar (4 Top)	\N	185.00	10.00	t	2026-03-30 20:41:09.623366+03	2026-03-30 21:18:37.029973+03	DONDURMALAR	\N
1061	96	Antep Keyfi	\N	250.00	10.00	t	2026-03-30 20:41:09.623366+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1460	24	çako	\N	1.00	10.00	f	2026-04-01 12:35:17.335534+03	2026-04-04 13:58:04.639729+03	SOĞUK İÇECEKLER	\N
1461	24	ujjj	\N	1.00	10.00	t	2026-04-06 13:19:35.920685+03	2026-04-06 13:19:35.920685+03	SOĞUK İÇECEKLER	\N
56	23	Sahlep	SIC-003	60.00	10.00	f	2026-03-22 18:28:23.448475+03	2026-04-06 23:16:42.958266+03	SICAK İÇECEKLER	\N
245	53	Tavuk Izgara	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
246	53	Acılı Kanat	\N	495.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
247	53	Köri Soslu Tavuk	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
248	53	Soya Soslu Tavuk	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
249	53	Piliç Şinitzel	\N	330.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
250	53	Tavuklu Fajita	\N	400.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Tavuk Yemekleri	\N
251	54	Chef Köfte Kaşarlı	\N	380.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
252	54	Bodrum Çökertmesi	\N	600.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
253	54	Gurme Bonfile	\N	700.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
254	54	Etli Fajita	\N	700.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
255	54	Güveçte Et Sote	\N	550.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
256	54	Chef Köfte	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
257	54	Steak Rulo	\N	700.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Et Yemekleri	\N
1164	106	Amsterdam	\N	350.00	10.00	t	2026-03-30 21:17:05.265056+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1165	106	Anason	\N	350.00	10.00	t	2026-03-30 21:17:05.265056+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1166	106	Arizona	\N	350.00	10.00	t	2026-03-30 21:17:05.265056+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1130	106	Ice Cola	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1131	106	Isabella	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1135	106	Lady Killer	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1137	106	Love 66	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1142	106	Milano	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1148	106	Paradise	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1150	106	Pinkman	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1152	106	Queen	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1160	106	Üzüm-Nane	\N	350.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1138	106	Lüle Değişim	\N	200.00	10.00	t	2026-03-30 21:01:32.182224+03	2026-03-30 21:22:45.644366+03	NARGİLE	\N
1163	107	Matcha	\N	220.00	10.00	t	2026-03-30 21:17:05.265056+03	2026-03-30 21:22:45.644366+03	MATCHA (MAÇA)	\N
1167	24	Buzlu Çikolata	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1168	24	Buzlu Beyaz Çikolata	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1171	24	Çilek Limon Aşkı	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1172	24	Dondurma Espresso Aşkı	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1173	24	Vişne - Muz Aşkı	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1174	24	Mavi Rüya	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1175	24	Chai Tea Latte	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1176	24	Green Heaven	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1177	24	Pinkberry	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1178	24	Caremella	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1179	24	Coco Choco	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1180	24	Deep Forest	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1182	24	Green Tea	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1183	24	Fresh Lime	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1184	24	Bubble Tea Frambuaz	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1185	24	Bubble Tea Çarkıfelek	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1186	24	Bubble Tea Limon	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1187	24	Bubble Tea Frenk	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1188	24	Bubble Tea Çilek	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1189	24	Green Wind	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1191	24	Rasberry Acai	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1192	24	Summer Breeze	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1193	24	Cloudy	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
1213	31	Parmak Patates ve Soğan Halkası	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
1225	84	Sütlü Çay	\N	80.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1226	84	Papatya	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1227	84	Adaçayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1228	84	Rezene	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1229	84	Ihlamur	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1230	84	Yeşil Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1231	84	Naneli Yeşil Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1232	84	Nane - Limon Yeşil Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1233	84	Limonlu Yeşil Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1234	84	Yaseminli Yeşil Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1235	84	Orman Meyveli Siyah Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1236	84	Limonlu Siyah Çay	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1237	84	Kuşburnu Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1238	84	Elma Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1239	84	Böğürtlen Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1240	84	Nar Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1241	84	Çilek Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1242	84	Nane – Limon Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1243	84	Winter Tea Çayı	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
1244	85	Sütlü Türk Kahvesi	\N	140.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1246	85	Türk Kahvesi	\N	120.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1247	85	Osmanlı Dibek Kahvesi	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1248	85	Osmanlı Dibek Damla Sakızlı Kahve	\N	140.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1249	85	Yeditepe İstanbul	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1250	85	Menengiç Kahvesi	\N	140.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1251	85	Leb-İ Derya Kahvesi	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1252	85	Damla Sakızlı Türk Kahvesi	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1253	85	Çikolata – Fındıklı Türk Kahvesi	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1254	85	Dağ Çilekli Türk Kahvesi	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1255	85	Double Aromalı Türk Kahvesi Çeşitleri	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
1256	86	Espresso	\N	130.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1257	86	Double Espresso	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1258	86	Espresso Macciato	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1259	86	Double Espresso Macciato	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1260	86	Espresso Con Panna	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1261	86	Double Espresso Con Panna	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1262	86	Oreo Hot Coffee	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1263	86	White Chocolate Mocha	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1264	86	Karamel Macchiato	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1265	86	Aromalı Cafe Latte	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1169	24	Çikolatalı Smoothie	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:45:27.347728+03	SOĞUK İÇECEKLER	\N
1267	86	Aromalı Cappucino	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1268	86	Latte Macchiato	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1269	86	Hazır Kahve Sade	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1270	86	Hazır Kahve Sütlü	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1271	86	Kahve Deryası Special	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1274	86	Cafe Mocha	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1275	86	Cortado	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1276	86	Flat White	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1277	86	Lotus Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1278	86	Antep Fıstıklı Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1279	86	Matcha	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1280	86	Hurma Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1281	86	Kestane Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1282	86	Apple Pie Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1283	86	Toffee Nut Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1284	86	Cookies Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1285	86	Vanilla Coconout Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1286	86	Zencefil Tarçın Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1287	86	Salted Caramel Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1288	86	Pumpkin Spice Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1289	86	Irish Cream Latte	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
1290	87	Filtre Kahve	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1291	87	Sütlü Filtre Kahve	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1292	87	Karamelli Filtre Kahve	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1293	87	Fındıklı Filtre Kahve	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1294	87	Ethiopia	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1295	87	Colombian Supremo	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1297	87	Guetemala Yirgacheffe	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
1298	88	Oreo Frappe	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FRAPPELER	\N
1299	88	White Mocha Frappe	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FRAPPELER	\N
1300	88	Dondurmalı Frappe	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FRAPPELER	\N
1301	88	Kahve Deryası Frappe	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FRAPPELER	\N
1302	88	Buzlu Hazır Kahve	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FRAPPELER	\N
1303	30	Leb-i Derya Kahvaltı (Yöresel Kahvaltı)	\N	800.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
1309	30	İtalyan Kahvaltısı	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
1325	26	Top Dondurma	\N	0.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	DONDURMALAR	\N
1328	38	Fettucini Alfredo	\N	320.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MAKARNALAR	\N
1330	38	Penne Arabiatta	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MAKARNALAR	\N
1331	38	Penne Al Fredo	\N	290.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MAKARNALAR	\N
1334	93	Citrus Pop	\N	195.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1335	93	Acai Moctails	\N	195.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1336	93	Red Bull White	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1337	93	Peach Twist	\N	240.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1338	93	Blue Twist	\N	240.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1339	93	White Twist	\N	240.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1340	93	Berry Me	\N	240.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1341	93	Passion Paradise	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1342	93	Pink Lemonade	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1343	93	Sour Island	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1344	93	Vanilla Inspration	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1345	93	Coca Cola Zero	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1346	93	Coca Cola	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1347	93	Coca Cola Light	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1348	93	Fanta	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1349	93	Sprite	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1351	93	Fusetea	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1352	93	Schweppes	\N	110.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1353	93	Pet Su	\N	30.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1354	93	Cam Şişe Su	\N	65.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1355	93	Meyveli Soda	\N	80.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1356	93	Soda	\N	70.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1357	93	Soda Limon	\N	90.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1358	93	Churchill	\N	100.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1359	93	Limonata	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1360	93	Meyveli Limonata	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1361	93	Taze Sıkılmış Portakal Suyu	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1362	93	Muzlu Süt	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1363	93	Ayran	\N	80.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1364	93	Red Bull Energy Drink	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1365	93	Red Bull Sugar Free	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1366	93	Red Bull Yellow Edition	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1367	93	Red Bull Blue Edition	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1368	93	Schweppespresso	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1369	93	Fix Cocktail	\N	195.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1370	93	Coke Mojito	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1371	93	Pineapple Pop	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1372	93	Red Bull Twist	\N	240.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1373	93	Tropical Breeze	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
1374	94	Tropicana Frozen	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEYVELİ FROZENLER	\N
1375	94	Çilekli Frozen	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEYVELİ FROZENLER	\N
1376	94	Kavunlu Frozen	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEYVELİ FROZENLER	\N
1377	94	Muzlu Frozen	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEYVELİ FROZENLER	\N
1378	94	Şeftali Frozen	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEYVELİ FROZENLER	\N
1379	94	Nane Limon Frozen	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MEYVELİ FROZENLER	\N
1381	95	Çikolata Milkshakes	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
1382	95	Çilek Milkshakes	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
1383	95	Muz Milkshakes	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
1384	95	Karamel Milkshakes	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
1385	95	Limon Milkshakes	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
1386	95	Oreo Milkshakes	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
1387	96	Kedi Dili Tiramisu	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1388	96	Belçika Çikolatalı Pasta	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1389	96	Coco Star	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1390	96	Brownie Karamel Cheesecake	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1391	96	Latte Mono Cake	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1392	96	Orman Meyveleri	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1393	96	Havuçlu Kek	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1394	96	Tiramisu	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1395	96	Frambuazlı Cheesecake	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1396	96	Limonlu Cheesecake	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1397	96	Kara Orman Pasta	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1398	96	Siyah Profiterollü Pasta	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1399	96	Mozaik Pasta	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1400	96	Devil's Fudge	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1401	96	Brownie	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1403	96	Sufle	\N	300.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1404	96	Nuthellalı Pasta	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1405	96	İspanyol Cream Cheesecake	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1406	96	Marlenka	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PASTA VE KEKLER	\N
1409	34	Vejeteryan Pizza	\N	270.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	PİZZALAR	\N
1412	98	Salep	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1413	98	Damla Sakızlı Salep	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1414	98	Damla Sakızlı - Fındık Parçacıklı Salep	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1415	98	Ballı - Bademli Salep	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1416	98	Sıcak Çikolata	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1417	98	Bitter Sıcak Çikolata	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1418	98	Dağ Çilekli Sıcak Çikolata	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1419	98	Beyaz Sıcak Çikolata	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1420	98	Aromalı Sıcak Çikolata	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SAHLEP-SICAK ÇİKOLATA	\N
1426	100	Affogato	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1427	100	Ice Antep Fıstıklı Latte	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1428	100	Ice Coffee Nut Latte	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1429	100	Ice Cafe Latte	\N	190.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1430	100	Iced Chai Tea Latte	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1431	100	Frappe	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1432	100	Buzlu Fındık	\N	180.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1433	100	Ice Americano	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1434	100	Ice Mocha	\N	220.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1435	100	Ice Caramel	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	SOĞUK KAHVELER	\N
1438	102	Cold Brew	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	YENİ NESİL KAHVELER	\N
1439	102	Cold Brew Sütlü	\N	210.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	YENİ NESİL KAHVELER	\N
1440	102	Chemex	\N	230.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	YENİ NESİL KAHVELER	\N
1442	103	Meyve Detoks	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	DETOKS	\N
1443	104	Madlen Çikolata Kutusu (750gr)	\N	690.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1444	104	Madlen Çikolata Kutusu (500gr)	\N	590.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1445	104	Çakıltaşı (100gr)	\N	150.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1446	104	Türk Kahvesi 100 Gr (Poşet)	\N	160.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1448	104	Filtre Kahve (100 Gr)	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1449	104	Aromalı Filtre Kahve (100gr)	\N	170.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1450	104	Kurabiye Çeşitleri	\N	200.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
1451	27	Waffle İdeal Çikolata, Mevsim Meyveleri	\N	270.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FONDU-WAFFLE	\N
1111	27	Waffle Mix	\N	300.00	10.00	t	2026-03-30 20:41:09.623366+03	2026-03-30 21:18:37.029973+03	FONDU-WAFFLE	\N
1453	27	Waffle Sade Çikolatalı	\N	250.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FONDU-WAFFLE	\N
1454	27	Karışık Çerez Tabağı	\N	280.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:18:37.029973+03	FONDU-WAFFLE	\N
1455	27	Tek Kişilik	\N	300.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:27:18.715111+03	FONDU-WAFFLE	\N
1456	27	Çift Kişilik	\N	400.00	10.00	t	2026-03-30 21:18:37.029973+03	2026-03-30 21:27:18.715111+03	FONDU-WAFFLE	\N
202	43	Karışık Menemen	\N	220.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Menemen	\N
203	43	Klasik Menemen	\N	170.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Menemen	\N
204	43	Kaşar Peynirli Menemen	\N	180.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Menemen	\N
205	43	Sucuklu Menemen	\N	190.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Menemen	\N
206	44	Sigara Böreği	\N	170.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Börekler	\N
207	44	Kalem Börek	\N	320.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Börekler	\N
208	45	Sıcak Sepet	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Atıştırmalıklar	\N
209	45	Parmak Patates	\N	180.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Atıştırmalıklar	\N
211	45	Elma Dilim Patates	\N	190.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Atıştırmalıklar	\N
212	45	Çıtır Tavuk Dilimleri	\N	250.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Atıştırmalıklar	\N
213	45	Dedikodu Tabağı	\N	400.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Atıştırmalıklar	\N
214	46	Kaşarlı Tost	\N	220.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Sandviçler / Tostlar	\N
215	46	Karışık Tost	\N	260.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Sandviçler / Tostlar	\N
216	46	Ton Balıklı Sandviç	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Sandviçler / Tostlar	\N
217	46	Karışık Sandviç	\N	300.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Sandviçler / Tostlar	\N
218	46	Philly Steak	\N	400.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Sandviçler / Tostlar	\N
219	46	Club Sandviç	\N	320.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Sandviçler / Tostlar	\N
220	47	Cheese Burger	\N	350.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Burgerler	\N
221	47	Big Chicken	\N	280.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Burgerler	\N
223	47	Cheese Mushroom Burger	\N	520.00	10.00	t	2026-03-28 16:06:29.43773+03	2026-03-30 20:41:09.623366+03	Burgerler	\N
493	24	Berriscus	\N	190.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
502	24	Orange Mango	\N	190.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	SOĞUK İÇECEKLER	\N
176	25	Beşamel Soslu Tavuk	\N	350.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
177	25	Tavuk Izgara	\N	350.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
482	24	Beyaz Çikolatalı Smoothie	\N	250.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:45:40.999908+03	SOĞUK İÇECEKLER	\N
178	25	Acılı Kanat	\N	495.00	10.00	f	2026-03-27 19:25:14.622773+03	2026-03-30 21:45:53.919361+03	ANA YEMEKLER	\N
172	25	Köri Soslu Tavuk	\N	350.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
173	25	Soya Soslu Tavuk	\N	350.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
174	25	Piliç Şinitzel	\N	330.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
175	25	Tavuklu Fajita	\N	400.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
180	25	Chef Köfte Kaşarlı	\N	380.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
181	25	Bodrum Çökertmesi	\N	600.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
182	25	Gurme Bonfile	\N	700.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
183	25	Etli Fajita	\N	700.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
184	25	Güveçte Et Sote	\N	550.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
179	25	Chef Köfte	\N	350.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
185	25	Steak Rulo	\N	700.00	10.00	t	2026-03-27 19:25:14.622773+03	2026-03-30 21:18:37.029973+03	ANA YEMEKLER	\N
136	31	Sıcak Sepet	\N	300.00	10.00	t	2026-03-27 19:11:59.295518+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
137	31	Parmak Patates	\N	180.00	10.00	t	2026-03-27 19:11:59.295518+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
139	31	Elma Dilim Patates	\N	190.00	10.00	t	2026-03-27 19:11:59.295518+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
140	31	Çıtır Tavuk Dilimleri	\N	250.00	10.00	t	2026-03-27 19:11:59.295518+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
141	31	Dedikodu Tabağı	\N	400.00	10.00	t	2026-03-27 19:11:59.295518+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
530	31	Kaşarlı Tost	\N	220.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
531	31	Karışık Tost	\N	260.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
532	31	Ton Balıklı Sandviç	\N	300.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
533	31	Karışık Sandviç	\N	300.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
534	31	Philly Steak	\N	400.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
535	31	Club Sandviç	\N	320.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	APERATİFLER	\N
609	87	Brazilian Santos	\N	190.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	FİLTRE KAHVELER	\N
119	30	Gevrek Kahvaltı Soğuk	\N	230.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
120	30	Gevrek Kahvaltı Sıcak	\N	250.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
121	30	Kahvaltı Tabağı	\N	350.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
122	30	Sahanda Yumurta	\N	120.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
124	30	Pişi Kahvaltı	\N	450.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
116	30	Sahanda Sucuklu Yumurta	\N	160.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
117	30	Bal Kaymak	\N	160.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
118	30	Peynir Tabağı	\N	220.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
126	30	Sade Omlet	\N	150.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
127	30	Beyaz Peynirli Omlet	\N	170.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
128	30	Kaşarlı Omlet	\N	175.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
129	30	Sucuklu Omlet	\N	180.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
125	30	Omlet Deryası	\N	220.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
133	30	Karışık Menemen	\N	220.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
130	30	Klasik Menemen	\N	170.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
131	30	Kaşar Peynirli Menemen	\N	180.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
132	30	Sucuklu Menemen	\N	190.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
135	30	Sigara Böreği	\N	170.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
134	30	Kalem Börek	\N	320.00	10.00	t	2026-03-27 19:09:47.216081+03	2026-03-30 21:18:37.029973+03	KAHVALTI VE BAŞLANGIÇLAR	\N
159	36	Etli Krep	\N	450.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	KREPLER	\N
160	36	Tavuklu Krep	\N	350.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	KREPLER	\N
171	38	Mantı	\N	300.00	10.00	t	2026-03-27 19:22:20.93582+03	2026-03-30 21:18:37.029973+03	MAKARNALAR	\N
168	38	Spagetti Napoliten	\N	250.00	10.00	t	2026-03-27 19:22:20.93582+03	2026-03-30 21:18:37.029973+03	MAKARNALAR	\N
169	38	Spagetti Bolognese	\N	300.00	10.00	t	2026-03-27 19:22:20.93582+03	2026-03-30 21:18:37.029973+03	MAKARNALAR	\N
664	93	Cappy	\N	110.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	MEŞRUBATLAR	\N
156	34	Karışık Pizza	\N	370.00	10.00	t	2026-03-27 19:17:04.931114+03	2026-03-30 21:18:37.029973+03	PİZZALAR	\N
152	34	Ton Balıklı Pizza	\N	370.00	10.00	t	2026-03-27 19:17:04.931114+03	2026-03-30 21:18:37.029973+03	PİZZALAR	\N
154	34	Pastırmalı Pizza	\N	400.00	10.00	t	2026-03-27 19:17:04.931114+03	2026-03-30 21:18:37.029973+03	PİZZALAR	\N
155	34	Margarita Pizza	\N	270.00	10.00	t	2026-03-27 19:17:04.931114+03	2026-03-30 21:18:37.029973+03	PİZZALAR	\N
536	84	Çay	\N	40.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
537	84	Fincan Çay	\N	70.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	ÇAYLAR	\N
558	85	Double Türk Kahvesi	\N	160.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	TÜRK KAHVESİ ÇEŞİTLERİ	\N
585	86	Americano	\N	170.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
586	86	Cafe Latte	\N	190.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	ESPRESSOLU KAHVELER	\N
694	95	Karadut Deryası Milkshakes	\N	250.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	MİLKSHAKELER	\N
162	37	Ege Usulü	\N	270.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	SALATALAR	\N
163	37	Diyet Salata	\N	300.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	SALATALAR	\N
164	37	Hellim Salata	\N	280.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	SALATALAR	\N
771	27	Meyve Tabağı	\N	250.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:27:18.715111+03	FONDU-WAFFLE	\N
165	37	Ton Balıklı Salata	\N	300.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	SALATALAR	\N
161	37	Tavuklu Sezar Salata	\N	300.00	10.00	t	2026-03-27 19:18:50.774388+03	2026-03-30 21:18:37.029973+03	SALATALAR	\N
750	101	Etli Wrap	\N	390.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	WRAPLAR	\N
751	101	Tavuklu Wrap	\N	290.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	WRAPLAR	\N
755	103	Yeşil Detoks	\N	230.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	DETOKS	\N
761	104	Aromalı Türk Kahvesi 100 Gr (Poşet)	\N	160.00	10.00	t	2026-03-28 16:16:36.497667+03	2026-03-30 21:18:37.029973+03	TAKE AWAY	\N
\.


--
-- Data for Name: tables; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.tables (id, table_code, display_name, capacity, is_active, created_at, updated_at, zone, is_custom) FROM stdin;
131	BALKON-10	Balkon 10	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
134	BALKON-13	Balkon 13	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
136	BALKON-15	Balkon 15	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
137	BALKON-16	Balkon 16	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
138	BALKON-17	Balkon 17	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
139	BALKON-18	Balkon 18	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
140	BALKON-19	Balkon 19	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
141	BALKON-20	Balkon 20	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
144	OYUN-3	Oyun Salonu 3	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
145	OYUN-4	Oyun Salonu 4	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
146	OYUN-5	Oyun Salonu 5	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
147	OYUN-6	Oyun Salonu 6	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
148	OYUN-7	Oyun Salonu 7	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
149	OYUN-8	Oyun Salonu 8	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
151	OYUN-10	Oyun Salonu 10	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
152	VIP-1	VIP 1	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	VIP	f
153	SALON-1	Salon 1	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Salon	f
154	SALON-2	Salon 2	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Salon	f
155	SALON-3	Salon 3	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Salon	f
156	SALON-4	Salon 4	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Salon	f
157	SALON-5	Salon 5	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Salon	f
158	SALON-6	Salon 6	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Salon	f
142	OYUN-1	Oyun Salonu 1	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
130	BALKON-9	Balkon 9	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
162	CUS-162	onur beyın masası	4	f	2026-03-25 21:44:55.385406+03	2026-03-27 19:41:17.199743+03	Balkon	t
160	CUS-160	oyun salonu 11	4	f	2026-03-24 19:30:48.547619+03	2026-03-27 19:41:26.423943+03	Oyun Salonu	t
159	CUS-159	balkon21	4	f	2026-03-24 19:11:04.210335+03	2026-03-27 19:41:30.096618+03	Balkon	t
161	CUS-161	Balkon 22	4	f	2026-03-25 21:41:30.039348+03	2026-03-27 19:41:34.052941+03	Balkon	t
135	BALKON-14	Balkon 14	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
133	BALKON-12	Balkon 12	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
126	BALKON-5	Balkon 5	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
128	BALKON-7	Balkon 7	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
124	BALKON-3	Balkon 3	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
125	BALKON-4	Balkon 4	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
150	OYUN-9	Oyun Salonu 9	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
163	CUS-163	Attila bey	4	f	2026-03-28 19:11:53.040988+03	2026-03-29 18:32:46.519091+03	Salon	t
143	OYUN-2	Oyun Salonu 2	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Oyun Salonu	f
164	CUS-164	Balkon 21	4	f	2026-03-29 22:18:06.659939+03	2026-03-29 23:13:12.596847+03	Balkon	t
165	CUS-165	VIP 2	4	t	2026-03-30 12:11:21.905624+03	2026-03-30 12:11:21.905624+03	VIP	t
166	CUS-166	VIP 3	4	t	2026-03-30 12:11:27.033743+03	2026-03-30 12:11:27.033743+03	VIP	t
167	CUS-167	VIP 4	4	t	2026-03-30 12:11:30.228416+03	2026-03-30 12:11:30.228416+03	VIP	t
168	CUS-168	VIP 5	4	t	2026-03-30 12:11:32.935966+03	2026-03-30 12:11:32.935966+03	VIP	t
169	CUS-169	VIP 6	4	t	2026-03-30 12:11:35.878313+03	2026-03-30 12:11:35.878313+03	VIP	t
129	BALKON-8	Balkon 8	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
122	BALKON-1	Balkon 1	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
132	BALKON-11	Balkon 11	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
127	BALKON-6	Balkon 6	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
123	BALKON-2	Balkon 2	4	t	2026-03-22 18:28:23.448475+03	2026-03-22 18:28:23.448475+03	Balkon	f
\.


--
-- Data for Name: users; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.users (id, full_name, pin_code, role_id, is_active, created_at, updated_at) FROM stdin;
1	Garson Kullanıcı	122323	2	t	2026-03-21 01:51:50.52912+03	2026-04-06 23:16:13.126648+03
3	Admin Kullanıcı	062362	1	t	2026-03-21 01:51:50.52912+03	2026-04-06 23:16:13.126648+03
2	Müdür Kullanıcı	2222	1	f	2026-03-21 01:51:50.52912+03	2026-04-06 23:16:13.126648+03
\.


--
-- Data for Name: voids; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.voids (id, order_id, order_item_id, product_id, action_type, quantity, reason, created_by_user_id, created_at) FROM stdin;
1	2	\N	493	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-01 12:26:02.982624+03
2	3	\N	493	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-01 12:30:29.855332+03
3	5	\N	493	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-01 12:32:22.369993+03
4	4	\N	176	VOID	2.00	POS üzerinden ürün iptali	3	2026-04-01 12:33:13.314255+03
5	11	\N	1227	VOID	7.00	POS üzerinden ürün iptali	3	2026-04-04 18:41:32.973723+03
6	10	\N	1252	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-05 14:24:17.247753+03
7	10	\N	1254	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-05 14:24:24.428169+03
8	20	\N	536	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-06 01:59:17.026331+03
9	39	\N	1239	VOID	3.00	POS üzerinden ürün iptali	3	2026-04-06 12:48:57.772413+03
10	38	132	1413	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-06 13:19:53.856258+03
11	38	130	1420	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-06 13:20:04.583833+03
12	40	\N	1252	VOID	2.00	POS üzerinden ürün iptali	3	2026-04-06 20:34:17.512169+03
13	40	\N	1247	VOID	1.00	POS üzerinden ürün iptali	3	2026-04-06 20:34:21.894113+03
14	40	\N	1252	VOID	2.00	POS üzerinden ürün iptali	3	2026-04-06 20:34:26.701944+03
\.


--
-- Data for Name: z_reports; Type: TABLE DATA; Schema: public; Owner: postgres
--

COPY public.z_reports (id, report_date, total_revenue, cash_total, card_total, total_orders, total_subtotal, total_vat, generated_by_user_id, payload, created_at, updated_at) FROM stdin;
1	2026-04-01	190.00	190.00	0.00	1	190.00	17.27	3	{"date": "2026-04-01T09:30:56.209Z", "totalVat": 17.272727272727273, "cardTotal": 0, "cashTotal": 190, "totalOrders": 1, "orderDetails": "#1 - Masa: Balkon 1 - CASH - 190.00 TL", "totalRevenue": 190, "totalSubtotal": 190}	2026-04-01 12:30:56.209876+03	2026-04-01 12:30:56.209876+03
2	2026-04-04	1.00	1.00	0.00	1	1.00	0.09	3	{"date": "2026-04-04T15:17:20.339Z", "totalVat": 0.09090909090909091, "cardTotal": 0, "cashTotal": 1, "totalOrders": 1, "orderDetails": "#7 - Masa: Balkon 1 - CASH - 1.00 TL", "totalRevenue": 1, "totalSubtotal": 1}	2026-04-04 18:17:20.342234+03	2026-04-04 18:17:20.342234+03
3	2026-04-05	8790.00	8790.00	0.00	9	8790.00	799.09	3	{"date": "2026-04-05T11:29:47.861Z", "totalVat": 799.0909090909091, "cardTotal": 0, "cashTotal": 8790, "totalOrders": 9, "orderDetails": "#15 - Masa: Balkon 14 - CASH - 400.00 TL\\n#8 - Masa: Balkon 2 - CASH - 1270.00 TL\\n#13 - Masa: Balkon 9 - CASH - 450.00 TL\\n#18 - Masa: Balkon 1 - CASH - 2400.00 TL\\n#16 - Masa: Oyun Salonu 1 - CASH - 170.00 TL\\n#17 - Masa: Balkon 1 - CASH - 80.00 TL\\n#12 - Masa: Oyun Salonu 1 - CASH - 2330.00 TL\\n#14 - Masa: Balkon 4 - CASH - 150.00 TL\\n#9 - Masa: Balkon 1 - CASH - 1540.00 TL", "totalRevenue": 8790, "totalExpenses": 0, "totalSubtotal": 8790}	2026-04-05 14:29:47.862052+03	2026-04-05 14:29:47.862052+03
4	2026-04-06	32061.00	31691.00	370.00	8	92061.00	2914.64	3	{"date": "2026-04-06T19:06:25.972Z", "totalVat": 2914.6363636363635, "cardTotal": 370, "cashTotal": 31691, "totalOrders": 8, "orderDetails": "#41 - Masa: Balkon 2 - CASH - 200.00 TL\\n#38 - Masa: Balkon 11 - CASH - 1291.00 TL\\n#39 - Masa: Balkon 1 - CASH - 2220.00 TL\\n#35 - Masa: Balkon 8 - CASH - 7330.00 TL\\n#31 - Masa: Balkon 1 - CASH - 6670.00 TL\\n#30 - Masa: Balkon 11 - CASH - 10000.00 TL\\n#29 - Masa: Balkon 1 - CARD - 370.00 TL\\n#25 - Masa: Balkon 4 - CASH - 3980.00 TL", "totalRevenue": 32061, "totalExpenses": 4000, "totalSubtotal": 92061}	2026-04-06 12:37:49.011055+03	2026-04-06 22:06:25.972521+03
\.


--
-- Name: categories_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.categories_id_seq', 158, true);


--
-- Name: expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.expenses_id_seq', 1, true);


--
-- Name: order_items_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.order_items_id_seq', 180, true);


--
-- Name: orders_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.orders_id_seq', 43, true);


--
-- Name: payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.payments_id_seq', 36, true);


--
-- Name: products_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.products_id_seq', 1461, true);


--
-- Name: tables_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.tables_id_seq', 169, true);


--
-- Name: users_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.users_id_seq', 23, true);


--
-- Name: voids_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.voids_id_seq', 14, true);


--
-- Name: z_reports_id_seq; Type: SEQUENCE SET; Schema: public; Owner: postgres
--

SELECT pg_catalog.setval('public.z_reports_id_seq', 5, true);


--
-- Name: categories categories_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_name_key UNIQUE (name);


--
-- Name: categories categories_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.categories
    ADD CONSTRAINT categories_pkey PRIMARY KEY (id);


--
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);


--
-- Name: order_items order_items_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_pkey PRIMARY KEY (id);


--
-- Name: orders orders_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_pkey PRIMARY KEY (id);


--
-- Name: payments payments_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_pkey PRIMARY KEY (id);


--
-- Name: products products_category_id_name_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_name_key UNIQUE (category_id, name);


--
-- Name: products products_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_pkey PRIMARY KEY (id);


--
-- Name: tables tables_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_pkey PRIMARY KEY (id);


--
-- Name: tables tables_table_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.tables
    ADD CONSTRAINT tables_table_code_key UNIQUE (table_code);


--
-- Name: users users_pin_code_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pin_code_key UNIQUE (pin_code);


--
-- Name: users users_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.users
    ADD CONSTRAINT users_pkey PRIMARY KEY (id);


--
-- Name: voids voids_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voids
    ADD CONSTRAINT voids_pkey PRIMARY KEY (id);


--
-- Name: z_reports z_reports_pkey; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_reports
    ADD CONSTRAINT z_reports_pkey PRIMARY KEY (id);


--
-- Name: z_reports z_reports_report_date_key; Type: CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_reports
    ADD CONSTRAINT z_reports_report_date_key UNIQUE (report_date);


--
-- Name: idx_expenses_expense_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_expenses_expense_date ON public.expenses USING btree (expense_date);


--
-- Name: idx_order_items_category_snapshot; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_order_items_category_snapshot ON public.order_items USING btree (category_snapshot);


--
-- Name: idx_order_items_order_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_order_items_order_id ON public.order_items USING btree (order_id);


--
-- Name: idx_order_items_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_order_items_status ON public.order_items USING btree (item_status);


--
-- Name: idx_orders_closed_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_closed_at ON public.orders USING btree (closed_at);


--
-- Name: idx_orders_status; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_status ON public.orders USING btree (order_status);


--
-- Name: idx_orders_table_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_table_id ON public.orders USING btree (table_id);


--
-- Name: idx_orders_waiter_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_orders_waiter_id ON public.orders USING btree (waiter_id);


--
-- Name: idx_payments_order_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_order_id ON public.payments USING btree (order_id);


--
-- Name: idx_payments_paid_at; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_payments_paid_at ON public.payments USING btree (paid_at);


--
-- Name: idx_products_category_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_products_category_id ON public.products USING btree (category_id);


--
-- Name: idx_voids_order_id; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_voids_order_id ON public.voids USING btree (order_id);


--
-- Name: idx_z_reports_report_date; Type: INDEX; Schema: public; Owner: postgres
--

CREATE INDEX idx_z_reports_report_date ON public.z_reports USING btree (report_date);


--
-- Name: expenses expenses_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- Name: order_items order_items_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: order_items order_items_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.order_items
    ADD CONSTRAINT order_items_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: orders orders_closed_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_closed_by_user_id_fkey FOREIGN KEY (closed_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: orders orders_opened_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_opened_by_user_id_fkey FOREIGN KEY (opened_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: orders orders_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_table_id_fkey FOREIGN KEY (table_id) REFERENCES public.tables(id) ON DELETE RESTRICT;


--
-- Name: orders orders_waiter_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.orders
    ADD CONSTRAINT orders_waiter_id_fkey FOREIGN KEY (waiter_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: payments payments_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE RESTRICT;


--
-- Name: payments payments_received_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.payments
    ADD CONSTRAINT payments_received_by_user_id_fkey FOREIGN KEY (received_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: products products_category_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.products
    ADD CONSTRAINT products_category_id_fkey FOREIGN KEY (category_id) REFERENCES public.categories(id) ON DELETE RESTRICT;


--
-- Name: voids voids_created_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voids
    ADD CONSTRAINT voids_created_by_user_id_fkey FOREIGN KEY (created_by_user_id) REFERENCES public.users(id) ON DELETE RESTRICT;


--
-- Name: voids voids_order_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voids
    ADD CONSTRAINT voids_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id) ON DELETE CASCADE;


--
-- Name: voids voids_order_item_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voids
    ADD CONSTRAINT voids_order_item_id_fkey FOREIGN KEY (order_item_id) REFERENCES public.order_items(id) ON DELETE SET NULL;


--
-- Name: voids voids_product_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.voids
    ADD CONSTRAINT voids_product_id_fkey FOREIGN KEY (product_id) REFERENCES public.products(id) ON DELETE RESTRICT;


--
-- Name: z_reports z_reports_generated_by_user_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: postgres
--

ALTER TABLE ONLY public.z_reports
    ADD CONSTRAINT z_reports_generated_by_user_id_fkey FOREIGN KEY (generated_by_user_id) REFERENCES public.users(id) ON DELETE SET NULL;


--
-- PostgreSQL database dump complete
--

\unrestrict JngoKsR7Oreb9dFSULRoDVuzUd6JjdWD49aa9xITkOeyJkWT9szQzA1OOJ3EVQS

