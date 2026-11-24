import { useEffect, useState } from "react";
import { fetchCatalog } from "@/lib/api";
import type { CatalogEntry } from "@/lib/exercises";

// useCatalog — каталог упражнений с сервера; null, пока ответ не пришёл
export function useCatalog(): CatalogEntry[] | null {
  const [catalog, setCatalog] = useState<CatalogEntry[] | null>(null);
  useEffect(() => {
    let alive = true;
    fetchCatalog().then((entries) => alive && setCatalog(entries));
    return () => {
      alive = false;
    };
  }, []);
  return catalog;
}
