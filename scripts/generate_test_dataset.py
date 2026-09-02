import csv
import random
import sys

def generate_csv(filename="sample_store_discounts_10k.csv", count=10000):
    print(f"Generating {count} mock retail SKUs into '{filename}'...")
    
    categories = ["Electronics", "Apparel", "Home & Kitchen", "Toys & Games", "Sporting Goods", "Beauty", "Automotive", "Grocery"]
    locations = ["Aisle 1", "Aisle 3", "Aisle 7 B2", "Endcap 4", "Bin 12", "Rack C", "Backroom Clearance"]

    headers = [
        "Item Barcode", 
        "Product Description", 
        "Department", 
        "Original Price", 
        "Promo Discount Price", 
        "Store Location"
    ]

    with open(filename, mode="w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(headers)

        for i in range(1, count + 1):
            # Generate 12-digit UPC-A barcode
            barcode = f"0{random.randint(10000000000, 99999999999)}"
            orig_price = round(random.uniform(9.99, 299.99), 2)
            disc_price = round(orig_price * random.choice([0.5, 0.6, 0.7, 0.75, 0.8]), 2)
            cat = random.choice(categories)
            title = f"{cat} Item #{i:05d} Standard Edition"
            loc = random.choice(locations)

            writer.writerow([barcode, title, cat, f"${orig_price:.2f}", f"${disc_price:.2f}", loc])

    print(f"Successfully generated {filename} ({count} rows)!")

if __name__ == "__main__":
    rows = 10000
    if len(sys.argv) > 1:
        rows = int(sys.argv[1])
    generate_csv(count=rows)
