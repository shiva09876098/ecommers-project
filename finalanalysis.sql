-- Final Query to combine all approaches with Date Components (Day, Month, Year, Hour)
WITH CustomerSpending AS (
    SELECT 
        TRY_CAST(CID AS INT) AS CID, 
        SUM(TRY_CAST([Net Amount] AS DECIMAL)) AS Total_Spending
    FROM 
        ecommercedata
    GROUP BY 
        CID
),

DiscountUsage AS (
    SELECT 
        TRY_CAST(CID AS INT) AS CID, 
        COUNT(CASE WHEN [Discount Availed] = 'Yes' THEN 1 END) AS Discount_Transactions,
        COUNT(*) AS Total_Transactions,
        (COUNT(CASE WHEN [Discount Availed] = 'Yes' THEN 1 END) * 1.0 / COUNT(*)) AS Discount_Usage_Percentage
    FROM 
        ecommercedata
    GROUP BY 
        CID
),

CustomerFrequency AS (
    SELECT 
        TRY_CAST(CID AS INT) AS CID, 
        COUNT(*) AS Total_Transactions
    FROM 
        ecommercedata
    GROUP BY 
        CID
),

SalesPerformance AS (
    SELECT 
        [Product Category], 
        SUM(TRY_CAST([Net Amount] AS DECIMAL)) AS Total_Sales, 
        COUNT(*) AS Total_Transactions,
        AVG(TRY_CAST([Discount Amount (INR)] AS DECIMAL)) AS Avg_Discount_Amount
    FROM 
        ecommercedata
    GROUP BY 
        [Product Category]
),

ContributionToSales AS (
    SELECT 
        [Product Category], 
        SUM(TRY_CAST([Net Amount] AS DECIMAL)) AS Total_Sales, 
        (SUM(TRY_CAST([Net Amount] AS DECIMAL)) * 1.0 / 
        (SELECT SUM(TRY_CAST([Net Amount] AS DECIMAL)) FROM ecommercedata)) AS Percentage_Contribution
    FROM 
        ecommercedata
    GROUP BY 
        [Product Category]
),

HighSpenders AS (
    SELECT 
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY Total_Spending) OVER () AS Percentile_90
    FROM 
        CustomerSpending
),

TransactionPercentile AS (
    SELECT 
        PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY Total_Transactions) OVER () AS Percentile_90
    FROM 
        CustomerFrequency
),

RecentCategory AS (
    -- Convert Purchase Date to DATETIME and extract most recent category
    SELECT 
        TRY_CAST(CID AS INT) AS CID, 
        [Product Category], 
        TRY_CAST([Purchase Date] AS DATETIME) AS PurchaseDate,
        ROW_NUMBER() OVER (PARTITION BY TRY_CAST(CID AS INT) ORDER BY TRY_CAST([Purchase Date] AS DATETIME) DESC) AS RowNum
    FROM 
        ecommercedata
)

-- Final Query
SELECT 
    cs.CID, 
    cs.Total_Spending, 
    du.Discount_Usage_Percentage, 
    cf.Total_Transactions AS Customer_Total_Transactions,
    rc.[Product Category], -- Most recent category
    sp.Total_Sales AS Sales_Per_Product_Category,
    sp.Avg_Discount_Amount,
    cts.Percentage_Contribution,

    -- High Spender Segmentation
    CASE 
        WHEN cs.Total_Spending > (SELECT MAX(Percentile_90) FROM HighSpenders) 
        THEN 'High Spender' 
        ELSE 'Regular Spender'
    END AS Spender_Segment,

    -- Discount Seeker Segmentation
    CASE 
        WHEN du.Discount_Usage_Percentage > 0.7 
        THEN 'Discount Seeker' 
        ELSE 'Regular Shopper'
    END AS Discount_Segment,

    -- Frequent Shopper Segmentation
    CASE 
        WHEN cf.Total_Transactions > (SELECT MAX(Percentile_90) FROM TransactionPercentile) 
        THEN 'Frequent Shopper' 
        ELSE 'Occasional Shopper'
    END AS Frequency_Segment,

    -- Extract Day, Month, Year, Hour from the Purchase Date
    DAY(TRY_CAST(rc.PurchaseDate AS DATETIME)) AS Purchase_Day,
    MONTH(TRY_CAST(rc.PurchaseDate AS DATETIME)) AS Purchase_Month,
    YEAR(TRY_CAST(rc.PurchaseDate AS DATETIME)) AS Purchase_Year,
    DATEPART(HOUR, TRY_CAST(rc.PurchaseDate AS DATETIME)) AS Purchase_Hour

FROM 
    CustomerSpending cs
JOIN 
    DiscountUsage du ON cs.CID = du.CID
JOIN 
    CustomerFrequency cf ON cs.CID = cf.CID
JOIN 
    RecentCategory rc ON cs.CID = rc.CID AND rc.RowNum = 1 -- Use only the most recent category
JOIN 
    SalesPerformance sp ON rc.[Product Category] = sp.[Product Category]
JOIN 
    ContributionToSales cts ON cts.[Product Category] = sp.[Product Category];