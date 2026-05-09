import React from 'react'
import ElosStorage from './storage.js'
class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { error: null };
  }
  static getDerivedStateFromError(error) {
    return { error };
  }
  componentDidCatch(error, info) {
    console.error('[ELOS] error boundary:', error, info);
  }
  componentDidMount() {
    /* Auto-reset on Vite HMR so a hot-reload recovers without user action */
    if (import.meta.hot) {
      import.meta.hot.on('vite:afterUpdate', () => {
        if (this.state.error) this.setState({ error: null });
      });
    }
  }
  reset = () => {
    this.setState({ error: null });
  };
  hardReset = () => {
    if (window.confirm('Erase ALL local ELOS data and reload?')) {
      try { ElosStorage.clearAll(); } catch {}
      location.reload();
    }
  };
  render() {
    if (this.state.error) {
      return (
        <div style={{padding:'40px 24px',color:'var(--ink)',fontFamily:'inherit',height:'100%',display:'flex',flexDirection:'column',justifyContent:'center'}}>
          <div style={{fontSize:24,fontWeight:700,marginBottom:8}}>Something went wrong</div>
          <div style={{fontSize:14,color:'var(--ink-3)',marginBottom:16}}>
            ELOS hit an unexpected error. Your data is still safe locally.
          </div>
          <pre style={{fontSize:11,background:'var(--bg-card)',padding:12,borderRadius:8,color:'var(--ink-3)',whiteSpace:'pre-wrap',maxHeight:200,overflow:'auto',marginBottom:16}}>
            {String(this.state.error?.message || this.state.error)}
          </pre>
          <button className="btn-primary" onClick={this.reset} style={{marginBottom:8}}>Try again</button>
          <button className="btn-primary secondary" onClick={() => location.reload()} style={{marginBottom:8}}>Reload app</button>
          <button className="btn-primary secondary" onClick={this.hardReset} style={{color:'var(--bad)'}}>Erase data &amp; reload</button>
        </div>
      );
    }
    return this.props.children;
  }
}

export { ErrorBoundary };
