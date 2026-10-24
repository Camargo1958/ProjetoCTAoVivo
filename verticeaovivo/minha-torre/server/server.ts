import { createApp, analytics, genie, server, Plugin, toPlugin, type PluginManifest } from '@databricks/appkit';

class TorrePlugin extends Plugin {
  static manifest = {
    name: 'torre',
    displayName: 'Projeto Farol',
    description: 'Endpoints de apoio ao dashboard do Projeto Farol.',
    resources: {
      required: [],
      optional: [],
    },
  } as PluginManifest<'torre'>;

  injectRoutes(router: Parameters<Plugin['injectRoutes']>[0]) {
    this.route(router, {
      name: 'score-estouro',
      method: 'get',
      path: '/api/score-estouro',
      handler: async (_req, res) => {
        await Promise.resolve();

        const hasWarehouse = Boolean(process.env.DATABRICKS_WAREHOUSE_ID);

        if (!hasWarehouse) {
          res.json({ disponivel: false, linhas: 0 });
          return;
        }

        res.json({ disponivel: true, linhas: 0 });
      },
    });
  }
}

export const torre = toPlugin(TorrePlugin);

createApp({
  plugins: [
    analytics(),
    genie(),
    server(),
    torre(),
  ],
}).catch(console.error);
