/*
Домашнее задание по курсу MS SQL Server Developer в OTUS.
Занятие "02 - Оператор SELECT и простые фильтры, GROUP BY, HAVING".

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
-- ---------------------------------------------------------------------------

USE WideWorldImporters

/*
1. Посчитать среднюю цену товара, общую сумму продажи по месяцам.
Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Средняя цена за месяц по всем товарам
* Общая сумма продаж за месяц

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select datename(year, i.InvoiceDate) 'Year'
	,datename(month, i.InvoiceDate) 'Month'
	,avg(il.ExtendedPrice) 'Average'
	,sum(il.ExtendedPrice) 'Total'
from Sales.Invoices i
inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
group by datename(year, i.InvoiceDate)
	,datename(month, i.InvoiceDate)
order by datename(year, i.InvoiceDate)
	,datename(month, i.InvoiceDate)

/*
2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000

Вывести:
* Год продажи (например, 2015)
* Месяц продажи (например, 4)
* Общая сумма продаж

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select datename(year, i.InvoiceDate) 'Year'
	,datename(month, i.InvoiceDate) 'Month'
	,sum(il.ExtendedPrice) 'Total'
from Sales.Invoices i
inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
group by datename(year, i.InvoiceDate)
	,datename(month, i.InvoiceDate)
having sum(il.ExtendedPrice) > 4600000
order by datename(year, i.InvoiceDate)
	,datename(month, i.InvoiceDate)

/*
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.

Вывести:
* Год продажи
* Месяц продажи
* Наименование товара
* Сумма продаж
* Дата первой продажи
* Количество проданного

Продажи смотреть в таблице Sales.Invoices и связанных таблицах.
*/

select datename(year, i.InvoiceDate) 'Year'
	,datename(month, i.InvoiceDate) 'Month'
	,si.StockItemName
	,sum(il.Quantity) 'Quantity'
	,sum(il.ExtendedPrice) 'TotalPrice'
	,min(i.InvoiceDate) 'FirstDate'
from Sales.Invoices i
inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
inner join Warehouse.StockItems si on il.StockItemID = si.StockItemID
group by datename(year, i.InvoiceDate)
	,datename(month, i.InvoiceDate)
	,si.StockItemName
having sum(il.Quantity) < 50
order by datename(year, i.InvoiceDate)
	,datename(month, i.InvoiceDate)

-- ---------------------------------------------------------------------------
-- Опционально
-- ---------------------------------------------------------------------------
/*
Написать запросы 2-3 так, чтобы если в каком-то месяце не было продаж,
то этот месяц также отображался бы в результатах, но там были нули.

2. Отобразить все месяцы, где общая сумма продаж превысила 4 600 000
*/

with all_dates
as (
	select min(i.InvoiceDate) f_d
		,max(i.InvoiceDate) l_d
	from Sales.Invoices i
	
	union all
	
	select dateadd(month, 1, f_d)
		,l_d
	from all_dates
	where f_d < l_d
	)
select datename(year, ad.f_d) 'Year'
	,datename(month, ad.f_d) 'Month'
	,i.[Total]
from all_dates ad
left join (
	select year(i.InvoiceDate) 'Year'
		,month(i.InvoiceDate) 'Month'
		,sum(il.ExtendedPrice) 'Total'
	from Sales.Invoices i
	inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
	group by year(i.InvoiceDate)
		,month(i.InvoiceDate)
	having sum(il.ExtendedPrice) > 4600000
	) i on i.[Year] = year(ad.f_d)
	and i.[Month] = month(ad.f_d)
order by year(ad.f_d)
	,month(ad.f_d)

/* 
3. Вывести сумму продаж, дату первой продажи
и количество проданного по месяцам, по товарам,
продажи которых менее 50 ед в месяц.
Группировка должна быть по году,  месяцу, товару.
*/

with all_dates
as (
	select min(i.InvoiceDate) f_d
		,max(i.InvoiceDate) l_d
	from Sales.Invoices i
	
	union all
	
	select dateadd(month, 1, f_d)
		,l_d
	from all_dates
	where f_d < l_d
	)
select datename(year, ad.f_d) 'Year'
	,datename(month, ad.f_d) 'Month'
	,i.StockItemName
	,i.Quantity
	,i.TotalPrice
	,i.FirstDate
from all_dates ad
left join (
	select year(i.InvoiceDate) 'Year'
		,month(i.InvoiceDate) 'Month'
		,si.StockItemName
		,sum(il.Quantity) 'Quantity'
		,sum(il.ExtendedPrice) 'TotalPrice'
		,min(i.InvoiceDate) 'FirstDate'
	from Sales.Invoices i
	inner join Sales.InvoiceLines il on i.InvoiceID = il.InvoiceID
	inner join Warehouse.StockItems si on il.StockItemID = si.StockItemID
	group by year(i.InvoiceDate)
		,month(i.InvoiceDate)
		,si.StockItemName
	having sum(il.Quantity) < 50
	) i on i.[Year] = year(ad.f_d)
	and i.[Month] = month(ad.f_d)
order by year(ad.f_d)
	,month(ad.f_d)