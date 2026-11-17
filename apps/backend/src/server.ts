import 'dotenv/config';
import path from 'node:path';
import cors from 'cors';
import express, { Request, Response } from 'express';
import { BirBookType } from './services/cas-books.service.js';
import { IesEngineService } from './services/ies-engine.service.js';

export function createApp(engine: IesEngineService) {
  const app = express();
  app.use(cors());
  app.use(express.json({ limit: '5mb' }));

  app.get('/api/health', (_req: Request, res: Response) => {
    res.json({
      status: 'ok',
      service: 'IES Philippine BIR EIS & CAS Middleware',
      schemaVersion: 'v2.01',
      timestamp: new Date().toISOString(),
    });
  });

  app.get('/api/dashboard/summary', (req: Request, res: Response) => {
    const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
    res.json(engine.getDashboardSummary(taxpayerId));
  });

  app.post('/api/gateway/config', (req: Request, res: Response) => {
    const updated = engine.setGatewayConfig(req.body ?? {});
    res.json(updated);
  });

  app.get('/api/taxpayers', (_req: Request, res: Response) => {
    // Expose safe public fields + publicKeyPem (never leak raw privateKeyPem over public listing)
    const safe = engine.getTaxpayers().map((tp) => ({
      id: tp.id,
      workspaceId: tp.workspaceId,
      tin: tp.tin,
      taxType: tp.taxType,
      registeredName: tp.registeredName,
      businessName: tp.businessName,
      email: tp.email,
      eisCertId: tp.eisCertId,
      pttNumber: tp.pttNumber,
      keyId: tp.keyId,
      publicKeyPem: tp.publicKeyPem,
      branches: tp.branches,
      createdAt: tp.createdAt,
    }));
    res.json(safe);
  });

  app.post('/api/taxpayers', (req: Request, res: Response) => {
    try {
      const created = engine.registerTaxpayer(req.body);
      res.status(201).json(created);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'Invalid taxpayer input' });
    }
  });

  app.post('/api/taxpayers/:id/branches', (req: Request, res: Response) => {
    try {
      const branch = engine.addBranch(String(req.params.id), req.body);
      res.status(201).json(branch);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'Invalid branch input' });
    }
  });

  app.post('/api/taxpayers/:id/rotate-keys', (req: Request, res: Response) => {
    try {
      const tp = engine.rotateTaxpayerKeys(String(req.params.id));
      res.json({ id: tp.id, keyId: tp.keyId, publicKeyPem: tp.publicKeyPem });
    } catch (err) {
      res.status(404).json({ error: err instanceof Error ? err.message : 'Taxpayer not found' });
    }
  });

  app.get('/api/invoices', (req: Request, res: Response) => {
    const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
    res.json(engine.getInvoices(taxpayerId));
  });

  app.post('/api/invoices', async (req: Request, res: Response) => {
    try {
      const { forceInvalidPayload, ...body } = req.body ?? {};
      const record = await engine.ingestAndTransmitInvoice(
        { sourceSystem: body.sourceSystem ?? 'IES_UI', ...body },
        { forceInvalidPayload: Boolean(forceInvalidPayload) },
      );
      res.status(record.status === 'REJECTED' ? 422 : 201).json(record);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'Failed to process invoice' });
    }
  });

  app.post('/api/invoices/retry-queue', async (_req: Request, res: Response) => {
    const result = await engine.processRetryQueue();
    res.json(result);
  });

  app.post('/api/invoices/:id/credit-memo', async (req: Request, res: Response) => {
    try {
      const reason = typeof req.body?.reason === 'string' ? req.body.reason : undefined;
      const cm = await engine.issueCreditMemo(String(req.params.id), reason);
      res.status(201).json(cm);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'Credit memo error' });
    }
  });

  app.post('/api/connectors/xero', async (req: Request, res: Response) => {
    try {
      const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
      const record = await engine.ingestFromXero(req.body, taxpayerId);
      res.status(201).json(record);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'Xero mapping error' });
    }
  });

  app.post('/api/connectors/quickbooks', async (req: Request, res: Response) => {
    try {
      const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
      const record = await engine.ingestFromQuickBooks(req.body, taxpayerId);
      res.status(201).json(record);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'QuickBooks mapping error' });
    }
  });

  app.post('/api/connectors/odoo', async (req: Request, res: Response) => {
    try {
      const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
      const record = await engine.ingestFromOdoo(req.body, taxpayerId);
      res.status(201).json(record);
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'Odoo mapping error' });
    }
  });

  app.post('/api/connectors/csv', async (req: Request, res: Response) => {
    try {
      const csvText = typeof req.body?.csv === 'string' ? req.body.csv : '';
      const taxpayerId = typeof req.body?.taxpayerId === 'string' ? req.body.taxpayerId : undefined;
      const records = await engine.ingestFromCsvBatch(csvText, taxpayerId);
      res.status(201).json({ importedCount: records.length, records });
    } catch (err) {
      res.status(400).json({ error: err instanceof Error ? err.message : 'CSV import error' });
    }
  });

  app.get('/api/cas/books', (req: Request, res: Response) => {
    const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
    const bookType =
      typeof req.query.bookType === 'string'
        ? (req.query.bookType.toUpperCase() as BirBookType | 'ALL')
        : 'ALL';
    res.json(engine.getCasBooks({ taxpayerId, bookType }));
  });

  app.get('/api/statutory/slsp', (req: Request, res: Response) => {
    const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
    const kind = req.query.kind === 'PURCHASES' ? 'PURCHASES' : 'SALES';
    const period = typeof req.query.period === 'string' ? req.query.period : '202611';
    res.json(engine.generateSlsp(taxpayerId, kind, period));
  });

  app.get('/api/statutory/withholding', (req: Request, res: Response) => {
    const taxpayerId = typeof req.query.taxpayerId === 'string' ? req.query.taxpayerId : undefined;
    const kind = req.query.kind === 'QAP' ? 'QAP' : 'SAWT';
    const period = typeof req.query.period === 'string' ? req.query.period : '202612';
    res.json(engine.generateWithholdingDat(taxpayerId, kind, period));
  });

  app.get('/api/statutory/form2307/:invoiceId', (req: Request, res: Response) => {
    try {
      const payload = engine.generateForm2307ForInvoice(String(req.params.invoiceId));
      res.json(payload);
    } catch (err) {
      res.status(404).json({ error: err instanceof Error ? err.message : 'Invoice not found' });
    }
  });

  app.get('/api/audit-trail', (_req: Request, res: Response) => {
    res.json({
      verification: engine.auditTrail.verifyIntegrity(),
      entries: [...engine.auditTrail.getEntries()].reverse(),
    });
  });

  return app;
}

const isMainModule =
  process.argv[1] &&
  (process.argv[1].endsWith('server.ts') || process.argv[1].endsWith('server.js'));

if (isMainModule) {
  const port = Number(process.env.PORT ?? 4000);
  const dataPath = path.resolve(process.cwd(), 'data', 'ies-store.json');
  const engine = new IesEngineService({ persistPath: dataPath });

  engine.seedDefaultDemoDataIfEmpty().then(() => {
    const app = createApp(engine);
    app.listen(port, () => {
      console.log(`IES BIR EIS & CAS Server listening on http://localhost:${port}`);
      console.log(`Gateway Mode: ${engine.gateway.config.mode}`);
    });
  });
}
