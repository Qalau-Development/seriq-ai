// isActive — пункт навигации выбран, только когда открыта сама эта страница (у упражнений, занятия и итогов выбранного пункта нет)
export function isActive(pathname: string, href: string): boolean {
  const here = pathname.replace(/\/$/, "") || "/";
  if (href === "/login") return here === "/login" || here === "/register";
  return here === href;
}
