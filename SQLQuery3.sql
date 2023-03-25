--1.Importing the all table data.
SELECT * 
FROM Merged$;


--2.Unpivoting the columns showing the date into a tabular form .
DROP TABLE IF EXISTS UnpivotTable
SELECT [Country Name], [Country Code], [Indicator Name], Attribute AS Year, Value
INTO UnpivotTable
FROM Merged$
UNPIVOT (Value FOR Attribute IN ([1960], [1961], [1962], [1963], [1964], [1965], [1966], [1967], [1968], [1969], [1970], [1971], [1972], [1973], [1974], [1975], [1976], [1977], [1978], [1979], [1980], [1981], [1982], [1983], [1984], [1985], [1986], [1987], [1988], [1989], [1990], [1991], [1992], [1993], [1994], [1995], [1996], [1997], [1998], [1999], [2000], [2001], [2002], [2003], [2004], [2005], [2006], [2007], [2008], [2009], [2010], [2011], [2012], [2013], [2014], [2015], [2016], [2017], [2018], [2019], [2020], [2021])) AS unpivoted_columns;


--For cleaning purpose , indicator name is extracted before the deliminator " (...... " 
DROP TABLE IF EXISTS UnpivotTable1
SELECT [Country Name],[Country Code],LEFT([Indicator Name],CHARINDEX(' (',[Indicator Name])) AS Indicator,Year,Value
INTO UnpivotTable1
FROM UnpivotTable;

--Calculating the country GDP Growth on Year On Basis.
SELECT [Country Name],
		[Year],
		[Value] AS GDP,
		LAG([Value]) OVER(PARTITION BY [Country Code] ORDER BY [Year]) AS Previous_11yr_GDP,
		(([Value]/LAG([Value]) OVER(PARTITION BY [Country Code] ORDER BY [Year]))-1)*100 AS YOY_growth_percentage
FROM UnpivotTable1
WHERE [Indicator]='GDP' AND
	[Year] >2011;

--Using the Common Table Expression to find the average growth on the GDP of the country on YOY and finding the list of top 10 growing economy
WITH GDP_Table AS (
SELECT [Country Name],
		[Year],
		[Value] AS GDP,
		LAG([Value]) OVER(PARTITION BY [Country Code] ORDER BY [Year]) AS Previous_11yr_GDP,
		(([Value]/LAG([Value]) OVER(PARTITION BY [Country Code] ORDER BY [Year]))-1)*100 AS YOY_growth_percentage
FROM UnpivotTable1
WHERE [Indicator]='GDP' AND
	[Year] >2011)
SELECT TOP 10 [Country Name],
	AVG([YOY_growth_percentage]) AS TEN_Yr_AVG_Gwth
FROM GDP_Table
WHERE YOY_growth_percentage IS NOT NULL
GROUP BY [Country Name]
ORDER BY TEN_Yr_AVG_Gwth DESC;

--Creating a New Table set including GDP Data
SELECT [Country Name],
		[Year],
		[Value] AS GDP,
		LAG([Value]) OVER(PARTITION BY [Country Code] ORDER BY [Year]) AS Previous_11yr_GDP,
		(([Value]/LAG([Value]) OVER(PARTITION BY [Country Code] ORDER BY [Year]))-1)*100 AS YOY_growth_percentage
INTO GDPTable
FROM UnpivotTable1
WHERE [Indicator]='GDP' AND
	[Year] >2011;


--Grouping the country in three category based on the Average GDP growth of 10 Yr on 3 category ["High Growth","Medium Growth","Less Grwoth"]
WITH category_table AS 
(SELECT [Country Name],
	AVG([YOY_growth_percentage]) AS TEN_Yr_AVG_Gwth,
	NTILE(3) OVER(ORDER BY AVG([YOY_growth_percentage]) DESC) As Catergory_Score
FROM GDPTable
GROUP BY [Country Name])
SELECT [Country Name],TEN_Yr_AVG_Gwth,
CASE
WHEN Catergory_Score = 1 THEN 'High Growth'
WHEN Catergory_Score = 2 THEN 'Medium Growth'
ELSE 'Low Growth'
END AS Category
FROM category_table;

--Pivoting the unpivoted table on the basis of the indicator name to view the different macroeconomic indicators of the country
SELECT [Country Name],[Official exchange rate (LCU per US$, period average)] exchange_rate,[ External debt stocks, long-term (DOD, current US$) ] External_Debt,[Population, total] Population,[Total reserves (includes gold, current US$)] Reserve,[GDP (current US$)] GDP,[Inflation, consumer prices (annual %)] Inflation,[GNI per capita, Atlas method (current US$)] GNI_per_capita,[External balance on goods and services (current US$)] External_Trade 
INTO Yr_2021
FROM
  (SELECT [Country Name],[Indicator Name],[Year],[Value]
   FROM UnpivotTable) AS unp
PIVOT
  (MAX([Value]) FOR [Indicator Name] IN
    ([Official exchange rate (LCU per US$, period average)],[ External debt stocks, long-term (DOD, current US$) ],[Population, total],[Total reserves (includes gold, current US$)],[GDP (current US$)],[Inflation, consumer prices (annual %)],[GNI per capita, Atlas method (current US$)],[External balance on goods and services (current US$)]
)) pivoted_table
WHERE Year=2021;

--Creating the report view of the macroeconomic indicators and converting it to a comparable basis /population if needed.
WITH Report AS (
SELECT [Country Name],exchange_rate,(External_Debt/Population) Debt_per_capita,(Reserve/Population) Reserve_per_capita,(GDP/Population) GDP_per_capita,Inflation,GNI_per_capita
FROM Yr_2021)
SELECT [Country Name],
	Inflation,
RANK() OVER(ORDER BY Inflation ASC) Rank_Inflation,
	Debt_per_capita,
RANK() OVER(ORDER BY Debt_per_capita ASC) Rank_Debt,
	GNI_per_capita,
RANK() OVER(ORDER BY GNI_per_capita DESC) Rank_GNI,
	Reserve_per_capita,
RANK() OVER(ORDER BY Reserve_per_capita DESC) Rank_Reserve,
	GDP_per_capita,
RANK() OVER(ORDER BY GDP_per_capita DESC) Rank_Reserve
FROM Report
WHERE Inflation<>0 AND
	Debt_per_capita<>0 AND
	GNI_per_capita<>0 AND
	Reserve_per_capita<>0 AND
	GDP_per_capita<>0;

SELECT *
FROM Report;