/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.

Занятие "03 - Подзапросы, CTE, временные таблицы".

Задания выполняются с использованием базы данных WideWorldImporters.

Бэкап БД можно скачать отсюда:
https://github.com/Microsoft/sql-server-samples/releases/tag/wide-world-importers-v1.0
Нужен WideWorldImporters-Full.bak

Описание WideWorldImporters от Microsoft:
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-what-is
* https://docs.microsoft.com/ru-ru/sql/samples/wide-world-importers-oltp-database-catalog
*/

-- ---------------------------------------------------------------------------
-- Задание - написать выборки для получения указанных ниже данных.
-- Для всех заданий, где возможно, сделайте два варианта запросов:
--  1) через вложенный запрос
--  2) через WITH (для производных таблиц)
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Выберите сотрудников (Application.People), которые являются продажниками (IsSalesPerson), 
и не сделали ни одной продажи 04 июля 2015 года. 
Вывести ИД сотрудника и его полное имя. 
Продажи смотреть в таблице Sales.Invoices.
*/

select p.PersonID
	,p.FullName
from Application.People p
where p.IsSalesperson = 1
	and p.PersonID not in (
		select i.SalespersonPersonID
		from Sales.Invoices i
		where i.InvoiceDate = '20150704'
		);

with CTE_Invoices
as (
	select i.SalespersonPersonID
	from Sales.Invoices i
	where i.InvoiceDate = '20150704'
	)
select p.PersonID
	,p.FullName
from Application.People p
left join CTE_Invoices i on p.PersonID = i.SalespersonPersonID
where p.IsSalesperson = 1
	and i.SalespersonPersonID is null

/*
2. Выберите товары с минимальной ценой (подзапросом). Сделайте два варианта подзапроса. 
Вывести: ИД товара, наименование товара, цена.
*/

select si.StockItemID
	,si.StockItemName
	,si.UnitPrice
from Warehouse.StockItems si
where si.UnitPrice = (
		select min(UnitPrice)
		from Warehouse.StockItems
		);

select si.StockItemID
	,si.StockItemName
	,si.UnitPrice
from Warehouse.StockItems si
where si.UnitPrice = (
		select top 1 UnitPrice
		from Warehouse.StockItems
		order by UnitPrice asc
		);

with CTE_UnitPrice
as (
	select min(UnitPrice) UnitPrice
	from Warehouse.StockItems
	)
select si.StockItemID
	,si.StockItemName
	,si.UnitPrice
from Warehouse.StockItems si
inner join CTE_UnitPrice on si.UnitPrice = CTE_UnitPrice.UnitPrice

/*
3. Выберите информацию по клиентам, которые перевели компании пять максимальных платежей 
из Sales.CustomerTransactions. 
Представьте несколько способов (в том числе с CTE). 
*/

select c.CustomerID
	,c.CustomerName
from Sales.Customers c
where c.CustomerID in (
		select top 5 CustomerID
		from Sales.CustomerTransactions
		order by TransactionAmount desc
		);

with CTE_Transaction
as (
	select top 5 CustomerID
	from Sales.CustomerTransactions
	order by TransactionAmount desc
	)
select c.CustomerID
	,c.CustomerName
from Sales.Customers c
where exists (
		select CustomerID
		from CTE_Transaction
		where CustomerID = c.CustomerID
		);

with CTE_Transaction
as (
	select top 5 CustomerID
	from Sales.CustomerTransactions
	order by TransactionAmount desc
	)
select c.CustomerID
	,c.CustomerName
from Sales.Customers c
right join CTE_Transaction on c.CustomerID = CTE_Transaction.CustomerID

/*
4. Выберите города (ид и название), в которые были доставлены товары, 
входящие в тройку самых дорогих товаров, а также имя сотрудника, 
который осуществлял упаковку заказов (PackedByPersonID).
*/

select ac.CityID
	,ac.CityName
	,p.FullName
from Sales.Invoices i
inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
inner join Sales.Customers c on i.CustomerID = c.CustomerID
inner join Application.Cities ac on c.DeliveryCityID = ac.CityID
inner join Application.People p on i.PackedByPersonID = p.PersonID
where il.StockItemID in (
		select top 3 StockItemID
		from Warehouse.StockItems
		order by UnitPrice desc
		)
group by ac.CityID
	,ac.CityName
	,p.FullName;

with CTE_MaxStockItem
as (
	select top 3 StockItemID
	from Warehouse.StockItems
	order by UnitPrice desc
	)
select ac.CityID
	,ac.CityName
	,p.FullName
from Sales.Invoices i
inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
inner join CTE_MaxStockItem msi on msi.StockItemID = il.StockItemID
inner join Sales.Customers c on i.CustomerID = c.CustomerID
inner join Application.Cities ac on c.DeliveryCityID = ac.CityID
inner join Application.People p on i.PackedByPersonID = p.PersonID
group by ac.CityID
	,ac.CityName
	,p.FullName

-- ---------------------------------------------------------------------------
-- Опциональное задание
-- ---------------------------------------------------------------------------
-- Можно двигаться как в сторону улучшения читабельности запроса, 
-- так и в сторону упрощения плана\ускорения. 
-- Сравнить производительность запросов можно через SET STATISTICS IO, TIME ON. 
-- Если знакомы с планами запросов, то используйте их (тогда к решению также приложите планы). 
-- Напишите ваши рассуждения по поводу оптимизации. 

-- 5. Объясните, что делает и оптимизируйте запрос

SELECT 
	Invoices.InvoiceID, 
	Invoices.InvoiceDate,
	(SELECT People.FullName
		FROM Application.People
		WHERE People.PersonID = Invoices.SalespersonPersonID
	) AS SalesPersonName,
	SalesTotals.TotalSumm AS TotalSummByInvoice, 
	(SELECT SUM(OrderLines.PickedQuantity*OrderLines.UnitPrice)
		FROM Sales.OrderLines
		WHERE OrderLines.OrderId = (SELECT Orders.OrderId 
			FROM Sales.Orders
			WHERE Orders.PickingCompletedWhen IS NOT NULL	
				AND Orders.OrderId = Invoices.OrderId)	
	) AS TotalSummForPickedItems
FROM Sales.Invoices 
	JOIN
	(SELECT InvoiceId, SUM(Quantity*UnitPrice) AS TotalSumm
	FROM Sales.InvoiceLines
	GROUP BY InvoiceId
	HAVING SUM(Quantity*UnitPrice) > 27000) AS SalesTotals
		ON Invoices.InvoiceID = SalesTotals.InvoiceID
ORDER BY TotalSumm DESC

-- --

/*
Объяснение: Для счетов, сумма которых больше 27 000 долларов вывести id счета,
дату счета, имя продавца, итоговую сумму счета, итоговую сумму заказа (с заполенной датой комплектации)
*/

;

with CTE_Invoices -- Счета, сумма которых больше 27 000 долларов
as (
	select InvoiceId
		,sum(Quantity * UnitPrice) as TotalSumm
	from Sales.InvoiceLines
	group by InvoiceId
	having sum(Quantity * UnitPrice) > 27000
	)
	,CTE_SalesPerson -- Продавцы, оформившие счета
as (
	select i.InvoiceID
		,p.PersonID
		,p.FullName
	from CTE_Invoices ctei
	inner join Sales.Invoices i on i.InvoiceID = ctei.InvoiceID
	inner join Application.People p on p.PersonID = i.SalespersonPersonID
	)
select ctesp.InvoiceID -- Собираем все вместе
	,i.InvoiceDate
	,ctesp.FullName SalesPersonName
	,ctei.TotalSumm
	,sum(ol.PickedQuantity * ol.UnitPrice) TotalSummForPickedItems
from Sales.Invoices i
inner join CTE_Invoices ctei on i.InvoiceID = ctei.InvoiceID
inner join CTE_SalesPerson ctesp on ctei.InvoiceID = ctesp.InvoiceID
inner join Sales.OrderLines ol on ol.OrderID = i.OrderID
group by ctesp.InvoiceID
	,i.InvoiceDate
	,i.OrderID
	,ctesp.FullName
	,ctei.TotalSumm
order by TotalSummForPickedItems desc


/*
Переписал запрос, вынес подзапросы в CTE, запрос стал более читаемым и у меньшилось кол-во чтений таблиц

Изначальная стоимость запроса 9.17, стоимость оптимизированного запроса 2.4 
*/
