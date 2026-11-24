import type { Dict } from "@/lib/i18n";

interface MetaTag {
  getAttribute(name: string): string | null;
  setAttribute(name: string, value: string): void;
}

export interface MetaDocument {
  title: string;
  documentElement: { lang: string };
  querySelectorAll(selector: string): ArrayLike<MetaTag>;
  createElement(tag: string): MetaTag;
  head: { appendChild(node: unknown): unknown };
}

// applyDocumentMeta — заголовок вкладки, описание страницы и язык документа по выбранному языку; уже стоящие значения не трогает
export function applyDocumentMeta(doc: MetaDocument, lang: string, t: Dict) {
  if (doc.documentElement.lang !== lang) doc.documentElement.lang = lang;
  if (doc.title !== t.meta_title) doc.title = t.meta_title;
  const tags = Array.from(doc.querySelectorAll('meta[name="description"]'));
  if (tags.length === 0) {
    const tag = doc.createElement("meta");
    tag.setAttribute("name", "description");
    tag.setAttribute("content", t.meta_description);
    doc.head.appendChild(tag);
    return;
  }
  for (const tag of tags) if (tag.getAttribute("content") !== t.meta_description) tag.setAttribute("content", t.meta_description);
}

// watchDocumentMeta — держит заголовок и описание на выбранном языке: Next возвращает свои значения при переходах и при дозагрузке метаданных, поэтому следим за изменениями документа
export function watchDocumentMeta(doc: Document, lang: string, t: Dict): () => void {
  const apply = () => applyDocumentMeta(doc, lang, t);
  apply();
  const observer = new MutationObserver(apply);
  observer.observe(doc.documentElement, { childList: true, subtree: true, characterData: true });
  return () => observer.disconnect();
}
