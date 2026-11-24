/*
 * The module's own chart texts (totals in the tooltip, box plot statistics, default series and axis
 * names, the toolbox buttons it adds, the empty chart) in the languages of locales.js, so a chart with
 * -Locale de-DE does not mix German ECharts texts with English ones. The language is picked as for
 * ECharts' texts (language.js); anything else is English.
 */
import { echartsLocale } from "./language.js";

const EN = {
    total: "Total",
    totalSecondary: "Total (secondary axis)",
    max: "Max",
    min: "Min",
    median: "Median",
    outliers: "Outliers",
    count: "Count",
    price: "Price",
    volume: "Volume",
    fullScreen: "Full screen",
    noData: "No data"
};

// prettier-ignore
const TEXTS = {
    EN,
    DE: { total: "Gesamt", totalSecondary: "Gesamt (zweite Achse)", max: "Max", min: "Min", median: "Median", outliers: "Ausreißer", count: "Anzahl", price: "Preis", volume: "Volumen", fullScreen: "Vollbild", noData: "Keine Daten" },
    FR: { total: "Total", totalSecondary: "Total (axe secondaire)", max: "Max", min: "Min", median: "Médiane", outliers: "Valeurs aberrantes", count: "Nombre", price: "Prix", volume: "Volume", fullScreen: "Plein écran", noData: "Aucune donnée" },
    ES: { total: "Total", totalSecondary: "Total (eje secundario)", max: "Máx.", min: "Mín.", median: "Mediana", outliers: "Valores atípicos", count: "Recuento", price: "Precio", volume: "Volumen", fullScreen: "Pantalla completa", noData: "Sin datos" },
    IT: { total: "Totale", totalSecondary: "Totale (asse secondario)", max: "Max", min: "Min", median: "Mediana", outliers: "Valori anomali", count: "Conteggio", price: "Prezzo", volume: "Volume", fullScreen: "Schermo intero", noData: "Nessun dato" },
    NL: { total: "Totaal", totalSecondary: "Totaal (secundaire as)", max: "Max", min: "Min", median: "Mediaan", outliers: "Uitschieters", count: "Aantal", price: "Prijs", volume: "Volume", fullScreen: "Volledig scherm", noData: "Geen gegevens" },
    PL: { total: "Suma", totalSecondary: "Suma (oś pomocnicza)", max: "Maks.", min: "Min.", median: "Mediana", outliers: "Wartości odstające", count: "Liczba", price: "Cena", volume: "Wolumen", fullScreen: "Pełny ekran", noData: "Brak danych" },
    CS: { total: "Celkem", totalSecondary: "Celkem (vedlejší osa)", max: "Max", min: "Min", median: "Medián", outliers: "Odlehlé hodnoty", count: "Počet", price: "Cena", volume: "Objem", fullScreen: "Celá obrazovka", noData: "Žádná data" },
    SV: { total: "Totalt", totalSecondary: "Totalt (sekundär axel)", max: "Max", min: "Min", median: "Median", outliers: "Extremvärden", count: "Antal", price: "Pris", volume: "Volym", fullScreen: "Helskärm", noData: "Inga data" },
    FI: { total: "Yhteensä", totalSecondary: "Yhteensä (toissijainen akseli)", max: "Maks.", min: "Min.", median: "Mediaani", outliers: "Poikkeavat arvot", count: "Lukumäärä", price: "Hinta", volume: "Volyymi", fullScreen: "Koko näyttö", noData: "Ei tietoja" },
    "nb-NO": { total: "Totalt", totalSecondary: "Totalt (sekundærakse)", max: "Maks", min: "Min", median: "Median", outliers: "Uteliggere", count: "Antall", price: "Pris", volume: "Volum", fullScreen: "Fullskjerm", noData: "Ingen data" },
    "PT-br": { total: "Total", totalSecondary: "Total (eixo secundário)", max: "Máx.", min: "Mín.", median: "Mediana", outliers: "Valores atípicos", count: "Contagem", price: "Preço", volume: "Volume", fullScreen: "Tela cheia", noData: "Sem dados" },
    RU: { total: "Итого", totalSecondary: "Итого (вспомогательная ось)", max: "Макс.", min: "Мин.", median: "Медиана", outliers: "Выбросы", count: "Количество", price: "Цена", volume: "Объём", fullScreen: "Полный экран", noData: "Нет данных" },
    UK: { total: "Разом", totalSecondary: "Разом (допоміжна вісь)", max: "Макс.", min: "Мін.", median: "Медіана", outliers: "Викиди", count: "Кількість", price: "Ціна", volume: "Обсяг", fullScreen: "Повний екран", noData: "Немає даних" },
    TR: { total: "Toplam", totalSecondary: "Toplam (ikincil eksen)", max: "Maks.", min: "Min.", median: "Medyan", outliers: "Aykırı değerler", count: "Sayı", price: "Fiyat", volume: "Hacim", fullScreen: "Tam ekran", noData: "Veri yok" },
    JA: { total: "合計", totalSecondary: "合計（第2軸）", max: "最大", min: "最小", median: "中央値", outliers: "外れ値", count: "件数", price: "価格", volume: "出来高", fullScreen: "全画面表示", noData: "データなし" },
    ZH: { total: "合计", totalSecondary: "合计（次坐标轴）", max: "最大值", min: "最小值", median: "中位数", outliers: "异常值", count: "计数", price: "价格", volume: "成交量", fullScreen: "全屏", noData: "无数据" },
    KO: { total: "합계", totalSecondary: "합계 (보조 축)", max: "최대", min: "최소", median: "중앙값", outliers: "이상값", count: "개수", price: "가격", volume: "거래량", fullScreen: "전체 화면", noData: "데이터 없음" }
};

// the texts for a locale tag such as "de-DE"; English for a language locales.js does not have
export function textsFor(locale) {
    return TEXTS[echartsLocale(locale)] ?? EN;
}

// the languages with texts of their own, for the tests (EN and those of language.js)
export const TEXT_LANGUAGES = Object.keys(TEXTS);
