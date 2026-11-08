# Snapshots of addresses with a query string: file below data/ = the exact address it is fetched from.
# Every other file is the answer of https://<its path below data/> (Update-Data.ps1).
@{
    # daily weather of six cities (Berlin, London, Madrid, New York, Tokyo, Sydney), 2024 and 2025;
    # the showcase app of PowerShellUniversal.Component.Pivot.Demo asks for exactly this address
    'archive-api.open-meteo.com/v1/archive.json' = 'https://archive-api.open-meteo.com/v1/archive?latitude=52.52,51.51,40.42,40.71,35.69,-33.87&longitude=13.41,-0.13,-3.70,-74.01,139.69,151.21&start_date=2024-01-01&end_date=2025-12-31&daily=temperature_2m_max,temperature_2m_min,temperature_2m_mean,precipitation_sum,sunshine_duration&timezone=auto'
}
