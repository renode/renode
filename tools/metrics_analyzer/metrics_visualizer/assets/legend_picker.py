from matplotlib.widgets import CheckButtons


def set_legend_picker(fig, lines, legend):
    lined = dict()
    for legline, origline in zip(legend.get_lines(), lines):
        legline.set_picker(5)
        lined[legline] = origline

    def onpick(event):
        legline = event.artist
        origline = lined[legline]
        vis = not origline.get_visible()
        origline.set_visible(vis)
        if vis:
            legline.set_alpha(1.0)
        else:
            legline.set_alpha(0.2)
        fig.canvas.draw()

    fig.canvas.mpl_connect('pick_event', onpick)
