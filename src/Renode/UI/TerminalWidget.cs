//
// Copyright (c) 2010-2025 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Collections.Generic;

using Antmicro.Renode.Logging;
using Antmicro.Renode.Utilities;

using TermSharp;
using TermSharp.Rows;

using Xwt;
using Xwt.Drawing;

namespace Antmicro.Renode.UI
{
    public partial class TerminalWidget : Widget
    {
        public TerminalWidget(Func<bool> focusProvider, bool isMonitorWindow)
        {
            this.isMonitorWindow = isMonitorWindow;
            var shortcutDictionary = new Dictionary<KeyEventArgs, Action>
            {
                {CreateKey(Key.C, ModifierKeys.Shift | ModifierKeys.Control), CopyMarkedField},
                {CreateKey(Key.V, ModifierKeys.Shift | ModifierKeys.Control), PasteMarkedField},
                {CreateKey(Key.Insert, ModifierKeys.Shift), PasteMarkedField},
                {CreateKey(Key.Home, ModifierKeys.Shift), () => terminal.MoveScrollbarToBeginning() },
                {CreateKey(Key.End, ModifierKeys.Shift), () => terminal.MoveScrollbarToEnd() },
                {CreateKey(Key.PageUp, ModifierKeys.Shift), () => terminal.PageUp() },
                {CreateKey(Key.PageDown, ModifierKeys.Shift), () => terminal.PageDown() },
                {CreateKey(Key.Up, ModifierKeys.Shift), () => terminal.LineUp() },
                {CreateKey(Key.Down, ModifierKeys.Shift), () => terminal.LineDown() },
                {CreateKey(Key.Plus, ModifierKeys.Shift | ModifierKeys.Control), FontSizeUp},
                {CreateKey(Key.Minus, ModifierKeys.Control), FontSizeDown},
                {CreateKey(Key.NumPadAdd, ModifierKeys.Control), FontSizeUp},
                {CreateKey(Key.NumPadSubtract, ModifierKeys.Control), FontSizeDown},
                {CreateKey(Key.K0, ModifierKeys.Control), SetDefaultFontSize},
                {CreateKey(Key.NumPad0, ModifierKeys.Control), SetDefaultFontSize}
            };

            modifyLineEndings = ConfigurationManager.Instance.Get("termsharp", "append-CR-to-LF", true);
            terminal = new Terminal(focusProvider);
            IOSource = new TerminalIOSource(terminal);
            IOSource.BeforeWrite += b =>
            {
                // we do not check if previous byte was '\r', because it should not cause any problem to
                // send it twice
                if(modifyLineEndings && b == '\n')
                {
                    IOSource.Write((byte)'\r');
                }
            };

            terminal.InnerMargin = new WidgetSpacing(5, 5, 5, 5);
            terminal.Cursor.Enabled = true;
            terminal.ContextMenu = CreatePopupMenu();

            // We set the default font as a fall-back option.
            terminal.CurrentFont = Xwt.Drawing.Font.SystemMonospaceFont;
#if !PLATFORM_OSX
            // Here we try to load the robot font; unfortunately it doesn't work on OSX. Moreover, on some versions of
            // OSX it passes with no error (and no effect), on the others - it hangs. That's why we try to set the font and then
            // we check if we succeeded.
            var fontFile = typeof(TerminalWidget).Assembly.FromResourceToTemporaryFile("RobotoMono-Regular.ttf");
            Xwt.Drawing.Font.RegisterFontFromFile(fontFile);

#endif
            var fontFace = ConfigurationManager.Instance.Get("termsharp", "font-face", "Roboto Mono");
            defaultFontSize = ConfigurationManager.Instance.Get("termsharp", "font-size", (int)PredefinedFontSize, x => x >= MinFontSize);
            var font = Xwt.Drawing.Font.FromName(fontFace);
            if(!font.Family.Contains(fontFace))
            {
                Logger.Log(LogLevel.Warning, "The font '{0}' defined in the config file cannot be loaded.", fontFace);
                font = terminal.CurrentFont;
            }
            terminal.CurrentFont = font.WithSize(defaultFontSize);

            if(isMonitorWindow)
            {
                terminal.AppendRow(new ImageRow(Image.FromResource("logo.png"), 3), true);
            }
            // this empty dummy row is required as this is where first
            // characters will be displayed
            terminal.AppendRow(new MonospaceTextRow(""));

            var encoder = new TermSharp.Vt100.Encoder(x =>
            {
                terminal.ClearSelection();
                terminal.MoveScrollbarToEnd();
                IOSource.HandleInput(x);
            });

            terminal.ButtonPressed += (s, a) =>
            {
                if(a.Button == PointerButton.Middle)
                {
                    a.Handled = true;
                    PastePrimarySelection();
                }
            };

            terminal.KeyPressed += (s, a) =>
            {
                a.Handled = true;

                var modifiers = a.Modifiers;
                if(!Misc.IsOnOsX)
                {
                    modifiers &= ~(ModifierKeys.Command);
                }

                foreach(var entry in shortcutDictionary)
                {
                    if(modifiers == entry.Key.Modifiers)
                    {
                        if(a.Key == entry.Key.Key)
                        {
                            entry.Value();
                            return;
                        }
                    }
                }
                encoder.Feed(a.Key, modifiers);
            };
            Content = terminal;
        }

        public void Close()
        {
            base.Dispose(true);

            if(IOSource != null)
            {
                IOSource.Dispose();
                IOSource = null;
            }
            foreach(var menuItem in terminal.ContextMenu.Items)
            {
                if(menuItemsDelegates.TryGetValue(menuItem, out var handler))
                {
                    menuItem.Clicked -= handler;
                }
            }
            menuItemsDelegates.Clear();
            terminal.Close();
        }

        public void Clear()
        {
            terminal.Clear();
        }

        public TerminalIOSource IOSource
        {
            get;
            set;
        }

        public event Action Initialized
        {
            add
            {
                terminal.Initialized += value;
            }

            remove
            {
                terminal.Initialized -= value;
            }
        }

        protected override void OnBoundsChanged()
        {
            if(!isMonitorWindow)
            {
                var availableScreenSize = terminal.ScreenSize + terminal.InnerMarginBottom - MinimalBottomMargin;
                var rowHeight = terminal.GetScreenRow(0).LineHeight;
                var fullLinesCount = Math.Floor(availableScreenSize / rowHeight);
                var desiredScreenSize = rowHeight * fullLinesCount;
                terminal.InnerMarginBottom = Math.Floor(availableScreenSize - desiredScreenSize + MinimalBottomMargin);
            }

            base.OnBoundsChanged();
        }

        private Menu CreatePopupMenu()
        {
            var popup = new Menu();

            var copyItem = new MenuItem("Copy");
            menuItemsDelegates[copyItem] = delegate
            {
                CopyMarkedField();
            };
            copyItem.Clicked += menuItemsDelegates[copyItem];
            popup.Items.Add(copyItem);

            var pasteItem = new MenuItem("Paste");
            menuItemsDelegates[pasteItem] = delegate
            {
                PasteMarkedField();
            };
            pasteItem.Clicked += menuItemsDelegates[pasteItem];
            popup.Items.Add(pasteItem);

            var lineEndingsItem = new MenuItem(lineEndingsDictionary[!modifyLineEndings]);
            menuItemsDelegates[lineEndingsItem] = delegate
            {
                modifyLineEndings = !modifyLineEndings;
                lineEndingsItem.Label = lineEndingsDictionary[!modifyLineEndings];
                ConfigurationManager.Instance.Set("termsharp", "append-CR-to-LF", modifyLineEndings);
            };
            lineEndingsItem.Clicked += menuItemsDelegates[lineEndingsItem];
            popup.Items.Add(lineEndingsItem);

            return popup;
        }

        private KeyEventArgs CreateKey(Key key, ModifierKeys modifierKeys)
        {
            return new KeyEventArgs(key, modifierKeys, false, 0);
        }

        private bool modifyLineEndings;

        private readonly Dictionary<bool, string> lineEndingsDictionary = new Dictionary<bool, string>
        {
            {true, "Append '\\r' to line ending"},
            {false, "Do not append '\\r' to line ending"}
        };

        private readonly bool isMonitorWindow;
        private readonly double defaultFontSize;
        private readonly Terminal terminal;

        private readonly Dictionary<MenuItem, EventHandler> menuItemsDelegates = new Dictionary<MenuItem, EventHandler>();
        private const int MinimalBottomMargin = 2;

#if PLATFORM_LINUX
        private const double PredefinedFontSize = 10.0;
#else
        // Default font size on OSX and Windows is slightly larger than on generic Linux system.
        private const double PredefinedFontSize = 12.0;
#endif
        private const double MinFontSize = 1.0;
    }
}