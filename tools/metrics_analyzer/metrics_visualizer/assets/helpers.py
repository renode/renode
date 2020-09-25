import os

def save_fig(fig, fileName, options):    
    if options.output:
        output_path = os.path.join(options.output, fileName)
    else:
        output_path = fileName

    fig.savefig(output_path)