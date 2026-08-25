import pandas as pd
df = pd.read_parquet("model_artifacts/restaurants.parquet")
print(df.columns.tolist())
print(df.head(2))
print(len(df))