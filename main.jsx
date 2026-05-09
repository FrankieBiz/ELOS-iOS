import React from 'react'
import ReactDOM from 'react-dom/client'
import './styles.css'
import App from './app.jsx'

const isNative = !!(window.Capacitor?.isNativePlatform?.())

if (isNative) {
  document.documentElement.classList.add('capacitor')

  import('@capacitor/status-bar').then(({ StatusBar, Style }) => {
    StatusBar.setOverlaysWebView({ overlay: true }).catch(() => {})
    StatusBar.setStyle({ style: Style.Default }).catch(() => {})
  }).catch(() => {})

  import('@capacitor/keyboard').then(({ Keyboard }) => {
    Keyboard.setAccessoryBarVisible({ isVisible: false }).catch(() => {})
  }).catch(() => {})
}

ReactDOM.createRoot(document.getElementById('root')).render(<App />)
