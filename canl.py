import pandas as pd


df = pd.read_csv('flightsSmall_modified.csv')


df = df.iloc[:, 3:]


df['CANCELLED'] = df['CANCELLED'].map({0: 'NO', 1: 'YES'})


df.to_csv('flightsSmall_modified2.csv', index=False)