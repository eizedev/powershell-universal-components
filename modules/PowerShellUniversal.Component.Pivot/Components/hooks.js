import { useEffect, useState } from "react";
import { NARROW_QUERY } from "./prepare";

// true while the window is phone-sized (for the default height of the report and its placeholder)
export function useNarrowWindow() {
    const query = typeof window !== "undefined" && window.matchMedia ? window.matchMedia(NARROW_QUERY) : null;
    const [narrow, setNarrow] = useState(() => Boolean(query && query.matches));
    useEffect(() => {
        if (!query) return undefined;
        const onChange = () => setNarrow(query.matches);
        query.addEventListener("change", onChange);
        return () => query.removeEventListener("change", onChange);
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);
    return narrow;
}
