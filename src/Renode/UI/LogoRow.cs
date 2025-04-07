//
// Copyright (c) 2010-2018 Antmicro
//
// This file is licensed under the MIT License.
// Full license text is available in 'licenses/MIT.txt'.
//
using Antmicro.Renode.UserInterface;

using TermSharp;
using TermSharp.Rows;

using Xwt;
using Xwt.Drawing;

namespace Antmicro.Renode.UI
{
    public class LogoRow : MonospaceTextRow
    {
        public LogoRow() : base("")
        {
            image = Image.FromResource("logo.png");
        }

        public override double PrepareForDrawing(ILayoutParameters parameters)
        {
            var baseResult = base.PrepareForDrawing(parameters);
#pragma warning disable RECS0018 // Comparison of floating point numbers with equality operator
            // MonoDevelop complains about comparing double to a const int,
            // but we detect uninitialized case here, so it's ok.
            if(LineHeight == 0) // UI has not been initalized yet
#pragma warning restore RECS0018 // Comparison of floating point numbers with equality operator
            {
                return baseResult;
            }
            targetImageHeight = PreferedHeightInLines * LineHeight;
            ShellProvider.NumberOfDummyLines = PreferedHeightInLines;
            return baseResult;
        }

        public override void Draw(Context ctx, Rectangle selectedArea, SelectionDirection selectionDirection, TermSharp.SelectionMode selectionMode)
        {
            var scale = targetImageHeight / image.Height;
            ctx.Scale(scale, scale);
            ctx.DrawImage(image, new Point());
            ctx.Translate(0, -targetImageHeight);
            base.Draw(ctx, selectedArea, selectionDirection, selectionMode);
        }

        private double targetImageHeight;
        private readonly Image image;
        private const int PreferedHeightInLines = 3;
    }
}