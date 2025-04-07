//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using System;
using System.Text;

using Xwt;

namespace Antmicro.Renode.UI
{
    public partial class TerminalWidget
    {
        private void CopyMarkedField()
        {
            Clipboard.SetText(terminal.CollectClipboardData().Text);
        }

        private void PasteText(string text)
        {
            if(string.IsNullOrEmpty(text))
            {
                return;
            }
            var textAsBytes = Encoding.UTF8.GetBytes(text);
            foreach(var b in textAsBytes)
            {
                IOSource.HandleInput(b);
            }
        }

        private void PasteMarkedField()
        {
            PasteText(Clipboard.GetText());
        }

        private void PastePrimarySelection()
        {
            PasteText(Clipboard.GetPrimaryText());
        }

        private void FontSizeUp()
        {
            var newSize = terminal.CurrentFont.Size + 1;
            terminal.CurrentFont = terminal.CurrentFont.WithSize(newSize);
        }

        private void FontSizeDown()
        {
            var newSize = Math.Max(terminal.CurrentFont.Size - 1, 1.0);
            terminal.CurrentFont = terminal.CurrentFont.WithSize(newSize);
        }

        private void SetDefaultFontSize()
        {
            var newSize = defaultFontSize;
            terminal.CurrentFont = terminal.CurrentFont.WithSize(newSize);
        }
    }
}