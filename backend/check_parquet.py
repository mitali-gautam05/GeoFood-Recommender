import pandas as pd

a = pd.read_parquet("model_artifacts/restaurants.parquet")
b = pd.read_parquet("model_artifacts/restaurants_diet.parquet")

print("rows:", len(a), len(b))                                # dono 33707
print("same name order:", (a["name"].values == b["name"].values).all())  # True
print("same index:", a.index.equals(b.index))                 # True
print(b["diet"].value_counts(normalize=True))                 # ~87.6 / 8.3 / 4.1