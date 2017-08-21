﻿//
// Copyright (c) Antmicro
//
// This file is part of the Renode project.
// Full license details are defined in the 'LICENSE' file.
//
using System;
using Xwt;
using Emul8.Peripherals.UART;
using AntShell.Terminal;
using Emul8.Utilities;
using Emul8.Logging;
using TermSharp;
using System.Collections.Generic;
using TermSharp.Rows;

namespace Antmicro.Renode.UI
{
    public partial class TerminalWidget : Widget
    {
        public TerminalWidget(Func<bool> focusProvider)
        {
            var shortcutDictionary = new Dictionary<KeyEventArgs, Action>
            {
                {CreateKey(Key.C, ModifierKeys.Shift | ModifierKeys.Control), CopyMarkedField},
                {CreateKey(Key.V, ModifierKeys.Shift | ModifierKeys.Control), PasteMarkedField},
                {CreateKey(Key.Insert, ModifierKeys.Shift), PasteMarkedField},
                {CreateKey(Key.PageUp, ModifierKeys.Shift), () => terminal.PageUp() },
                {CreateKey(Key.PageDown, ModifierKeys.Shift), () => terminal.PageDown() },
                {CreateKey(Key.Plus, ModifierKeys.Shift | ModifierKeys.Control), FontSizeUp},
                {CreateKey(Key.Minus, ModifierKeys.Control), FontSizeDown},
                {CreateKey(Key.NumPadAdd, ModifierKeys.Control), FontSizeUp},
                {CreateKey(Key.NumPadSubtract, ModifierKeys.Control), FontSizeDown},
                {CreateKey(Key.K0, ModifierKeys.Control), SetDefaultFontSize},
                {CreateKey(Key.NumPad0, ModifierKeys.Control), SetDefaultFontSize}
            };

            modifyLineEndings = ConfigurationManager.Instance.Get("termsharp", "append-CR-to-LF", false);
            terminal = new Terminal(focusProvider);
            terminalInputOutputSource = new TerminalIOSource(terminal);
            IO = new IOProvider { Backend = terminalInputOutputSource };
            IO.BeforeWrite += b =>
            {
                // we do not check if previous byte was '\r', because it should not cause any problem to
                // send it twice
                if(modifyLineEndings && b == '\n')
                {
                    IO.Write((byte)'\r');
                }
            };

            terminal.InnerMargin = new WidgetSpacing(5, 5, 5, 5);
            terminal.Cursor.Enabled = true;
            terminal.ContextMenu = CreatePopupMenu();

            // We set the default font as a fall-back option.
            terminal.CurrentFont = Xwt.Drawing.Font.SystemMonospaceFont;
#if EMUL8_PLATFORM_LINUX
            // Here we try to load the robot font; unfortunately it doesn't work on OSX and Windows. Moreover, on some versions of
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

            if(!FirstWindowAlreadyShown)
            {
                terminal.AppendRow(new LogoRow());
                FirstWindowAlreadyShown = true;
                firstWindow = true;
            }
            else
            {
                terminal.AppendRow(new MonospaceTextRow(""));
            }

            var encoder = new TermSharp.Vt100.Encoder(x =>
            {
                terminal.ClearSelection();
                terminal.MoveScrollbarToEnd();
                terminalInputOutputSource.HandleInput(x);
            });

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

        public TerminalWidget(UARTBackend backend, Func<bool> focusProvider) : this(focusProvider)
        {
            backend.BindAnalyzer(IO);
        }

        public void Clear()
        {
            terminal.Clear();
        }

        public IOProvider IO { get; private set; }

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

        protected override void Dispose(bool disposing)
        {
            base.Dispose(disposing);

            if(IO != null)
            {
                IO.Dispose();
                IO = null;
            }
        }

        protected override void OnBoundsChanged()
        {
            if(!firstWindow)
            {
                var availableScreenSize = terminal.ScreenSize + terminal.InnerMarginBottom - MinimalBottomMargin;
                var rowHeight = ((MonospaceTextRow)terminal.GetScreenRow(0, false)).LineHeight;
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
            copyItem.Clicked += delegate
            {
                CopyMarkedField();
            };
            popup.Items.Add(copyItem);

            var pasteItem = new MenuItem("Paste");
            pasteItem.Clicked += delegate
            {
                PasteMarkedField();
            };
            popup.Items.Add(pasteItem);

            var lineEndingsItem = new MenuItem(lineEndingsDictionary[!modifyLineEndings]);
            lineEndingsItem.Clicked += delegate
            {
                modifyLineEndings = !modifyLineEndings;
                lineEndingsItem.Label = lineEndingsDictionary[!modifyLineEndings];
                ConfigurationManager.Instance.Set("termsharp", "append-CR-to-LF", modifyLineEndings);
            };
            popup.Items.Add(lineEndingsItem);

            return popup;
        }

        private KeyEventArgs CreateKey(Key key, ModifierKeys modifierKeys)
        {
            return new KeyEventArgs(key, modifierKeys, false, 0);
        }

        private Dictionary<bool, string> lineEndingsDictionary = new Dictionary<bool, string>
        {
            {true, "Append '\\r' to line ending"},
            {false, "Do not append '\\r' to line ending"}
        };

        private bool modifyLineEndings;
        private bool firstWindow;
        private static bool FirstWindowAlreadyShown;
        private double defaultFontSize;
        private Terminal terminal;
        private TerminalIOSource terminalInputOutputSource;
        private const int MinimalBottomMargin = 2;

#if EMUL8_PLATFORM_OSX
        // Default font size on OSX is slightly larger than on generic Linux system.
        private const double PredefinedFontSize = 12.0;
#else
        private const double PredefinedFontSize = 10.0;
#endif
        private const double MinFontSize = 1.0;
    }
}
