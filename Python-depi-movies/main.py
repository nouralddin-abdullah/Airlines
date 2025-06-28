import pandas as pd
import matplotlib.pyplot as plt


pd.set_option('display.max_rows', None)
pd.set_option('display.max_columns', None)

# Read the CSV file into a DataFrame
df_movies = pd.read_csv('mvies.csv')

# Display the first 5 rows
print(df_movies.head().to_markdown(index=False, numalign="left", stralign="left"))
# Count the occurrences of each genre
genre_counts = df_movies['genre'].value_counts()

# Create a bar chart
plt.figure(figsize=(10, 6))  # Adjust figure size if needed
genre_counts.plot(kind='bar')
plt.title('Distribution of Movie Genres')
plt.xlabel('Genre')
plt.ylabel('Number of Movies')
plt.xticks(rotation=45)  # Rotate x-axis labels for better readability
plt.show()  # Display the chart in a new window