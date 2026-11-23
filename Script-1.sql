-- создание таблиц
create table customers (
    customer_id INT primary key,
    first_name VARCHAR(50),
    last_name VARCHAR(50),
    gender VARCHAR(50),
    DOB DATE,
    job_title VARCHAR(100),
    job_industry_category VARCHAR(100),
    wealth_segment VARCHAR(50),
    deceased_indicator BOOLEAN,
    owns_car BOOLEAN,
    address VARCHAR(255),
    postcode VARCHAR(20),
    state VARCHAR(50),
    country VARCHAR(50),
    property_valuation DECIMAL(10, 2)
);

create table products (
    product_id INT primary key,
    brand VARCHAR(50),
    product_line VARCHAR(50),
    product_class VARCHAR(50),
    product_size VARCHAR(20),
    list_price DECIMAL(10, 2),
    standard_cost DECIMAL(10, 2)
);

create table orders (
    order_id INT primary key,
    customer_id INT,
    order_date TIMESTAMP,
    online_order BOOLEAN,
    order_status VARCHAR(50),
    foreign key (customer_id) references customers(customer_id)
);

create table order_items (
    order_item_id INT primary key,
    order_id INT,
    product_id INT,
    quantity INT,
    item_list_price_at_sale DECIMAL(10, 2),
    item_standard_cost_at_sale DECIMAL(10, 2),
    foreign key (order_id) references orders(order_id),
    foreign key (product_id) references products(product_id)
);



-- проверка на дубли
select customer_id, COUNT(*)
from customers
group by customer_id
having COUNT(*) > 1;




-- ШАГ 3

-- 1. Выведите id продукта и среднюю цену продажи (item_list_price_at_sale) для 5 продуктов с самой высокой средней ценой продажи.

select product_id, AVG(item_list_price_at_sale) as avg
from order_items
group by product_id
order by avg desc
limit 5;


-- 2. Рассчитайте общую стоимость заказа (item_list_price_at_sale * quantity) для каждого бренда продукта.

select products.brand, SUM(order_items.item_list_price_at_sale * order_items.quantity) as total
from products, order_items
where order_items.product_id = products.product_id
group by products.brand
order by total;


-- 3. Подсчитайте количество заказов за каждый месяц для каждого года. То есть необходимо вывести год, месяц и количество заказов.

select 
    extract(year from order_date) as order_year,
    extract(month from order_date) as order_month,
    COUNT(order_id) as orders_count
from orders
group by order_year, order_month
order by order_year, order_month;


-- 4. Для каждой продуктовой линейки (product_line) найдите продукт с самой высокой стандартной стоимостью (standard_cost). Выведите id продукта, линейку продукта и стандартную стоимость.

select distinct on (product_line) 
    product_id, 
    product_line, 
    standard_cost
from products
order by product_line, standard_cost desc;


-- 5. Подсчитайте количество заказов и общую стоимость заказов для каждого статуса заказа (order_status). Общую стоимость заказа необходимо рассчитать как цену продукта на момент продажи, умноженную на количество единиц продукта в заказе.

select 
    orders.order_status, 
    COUNT(distinct orders.order_id) as orders_count,
    SUM(order_items.item_list_price_at_sale * order_items.quantity) as total
from orders
join order_items on orders.order_id = order_items.order_id
group by orders.order_status;


-- 6. Найдите клиентов, у которых нет ни одного заказа. Выведите id клиента, фамилию и имя.

select customers.customer_id, customers.last_name, customers.first_name
from customers
left join orders on customers.customer_id = orders.customer_id
where orders.order_id is null;


-- 7. Для каждого штата найдите клиента с самой высокой и самой низкой оценкой стоимости имущества (property_valuation). Выведите штат, оценку стоимости имущества, фамилию и имя клиента.

with clients as (
    select 
        state, 
        property_valuation, 
        first_name, 
        last_name,
        ROW_NUMBER() over(partition by state order by property_valuation desc) as c_max,
        ROW_NUMBER() over(partition by  state order by property_valuation asc) as c_min
    from customers
)
select state, property_valuation, first_name, last_name
from clients
where c_max = 1 OR c_min = 1
order by state, property_valuation desc;


-- 8. Найдите клиентов, которые покупали продукты только из одной продуктовой линейки (product_line). Выведите id клиента, линейку продукта и количество заказов.

select 
    orders.customer_id, 
    products.product_line, 
    COUNT(distinct orders.order_id) as orders_count
from orders
join order_items on orders.order_id = order_items.order_id
join products on order_items.product_id = products.product_id
group by orders.customer_id, products.product_line
having COUNT(distinct products.product_line) = 1;


-- 9. Для каждой категории продуктов рассчитайте процент отмененных заказов (order_status = 'Cancelled').

select 
    products.product_class,
    COUNT(case when orders.order_status = 'Cancelled' then 1 end) * 100.0 / COUNT(orders.order_id) as percent
from orders
join order_items ON orders.order_id = order_items.order_id
join products ON order_items.product_id = products.product_id
group by products.product_class;


-- 10. Разделите клиентов на сегменты на основе количества заказов и подсчитайте количество клиентов в каждом сегменте

with orders_count as (
    select customer_id, COUNT(order_id) as total_orders
    from orders
    group by customer_id
)
select 
    case 
        when total_orders > 10 then 'High'
        when total_orders between 5 and 10 then 'Medium'
        else 'Low'
    end as segment,
    COUNT(customer_id) AS customers_count
from orders_count
group by segment;


-- 11. Для всех клиентов выведите имена, фамилии, профессии, а также длительность максимального интервала (в днях) между двумя последовательными заказами. Необходимо исключить клиентов, у которых только один заказ или меньше.

with intervals as (
    select 
        customer_id,
        order_date,
        lag(order_date) over(partition by customer_id order by order_date) as previous_order_date,
        COUNT(order_id) over(partition by customer_id) as total_orders
    from orders
)
select 
    customers.first_name, 
    customers.last_name, 
    customers.job_title,
    MAX(intervals.order_date::date - intervals.previous_order_date::date) as max_interval_days
from intervals
join customers on intervals.customer_id = customers.customer_id
where intervals.total_orders > 1 
  and intervals.previous_order_date is not null 
group by customers.customer_id, customers.first_name, customers.last_name, customers.job_title;





