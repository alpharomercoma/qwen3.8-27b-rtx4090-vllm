/** The app mark: an H in the accent square, the same drawing as the favicon. */
export function Mark({ size = 28 }: { size?: number }) {
  return (
    <svg width={size} height={size} viewBox="0 0 32 32" aria-hidden="true" className="shrink-0">
      <rect width="32" height="32" rx="8" fill="var(--accent)" />
      <path d="M10 8v16M22 8v16M10 16h12" stroke="var(--accent-ink)" strokeWidth="3.2" strokeLinecap="round" />
    </svg>
  );
}
