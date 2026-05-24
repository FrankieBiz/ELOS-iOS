function BottomSheet({ onClose, children, title }) {
  const { useEffect, useRef } = React;

  useEffect(() => {
    const handler = (e) => { if (e.key === 'Escape') onClose(); };
    window.addEventListener('keydown', handler);
    return () => window.removeEventListener('keydown', handler);
  }, [onClose]);

  return (
    <>
      <div className="sheet-backdrop" onClick={onClose} />
      <div className="sheet-panel">
        <div className="sheet-handle" />
        {title && (
          <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', padding: '16px 20px 0' }}>
            <span style={{ fontSize: 17, fontWeight: 700, color: 'var(--text)' }}>{title}</span>
            <button className="btn-ghost" onClick={onClose} style={{ padding: '4px 8px', fontSize: 15 }}>✕</button>
          </div>
        )}
        <div className="sheet-body">{children}</div>
      </div>
    </>
  );
}
