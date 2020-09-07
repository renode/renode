//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Threading;
using AntShell.Terminal;
using Antmicro.Renode.UI;
using Xwt;

namespace Antmicro.Renode.UI
{
    public class TermsharpProvider : IConsoleBackendAnalyzerProvider
    {
        public bool TryOpen(string consoleName, out IIOSource ioSource, bool isMonitorWindow = false)
        {
            TerminalWidget terminalWidget = null;
            ApplicationExtensions.InvokeInUIThreadAndWait(() =>
            {
                terminalWidget = new TerminalWidget(() => window.HasFocus, isMonitorWindow);
            });
            ioSource = terminalWidget.IOSource;

            var mre = new ManualResetEventSlim();
            ApplicationExtensions.InvokeInUIThread(() =>
            {
                window = new Window();
#if PLATFORM_WINDOWS
                window.Icon = Xwt.Drawing.Image.FromResource("renode_nobg.ico");
#endif
                window.Title = consoleName == null ? "Renode" : consoleName;
                window.Width = 700;
                window.Height = 400;
                var windowLocation = WindowPositionProvider.Instance.GetNextPosition();
                window.Location = windowLocation;
                window.Padding = new WidgetSpacing();
                window.Content = terminalWidget;
                terminalWidget.Initialized += mre.Set;
                window.Show();
                // window.Show() sets Location off screen if scaling > 100% on Windows
                window.Location = windowLocation;
                window.Closed += (sender, e) =>
                {
                    InnerOnClose();
                };
            });
            mre.Wait();

            return true;
        }

        public void Close()
        {
            var w = window;
            if(w != null)
            {
                ApplicationExtensions.InvokeInUIThreadAndWait(() =>
                {
                    w.Hide();
                });
                w = null;
                return;
            }
        }

        public event Action OnClose;

        private void InnerOnClose()
        {
            OnClose?.Invoke();
        }

        private Xwt.Window window;
    }
}
