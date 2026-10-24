import {
  useAnalyticsQuery,
  Card,
  CardContent,
  CardHeader,
  CardTitle,
  Label,
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
  Skeleton,
  GenieChat,
} from '@databricks/appkit-ui/react';
import { useEffect, useMemo, useState } from 'react';

const currency = new Intl.NumberFormat('pt-BR', {
  style: 'currency',
  currency: 'BRL',
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const numberFmt = new Intl.NumberFormat('pt-BR', {
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const toNumber = (value: unknown) => {
  const number = Number(value);
  return Number.isFinite(number) ? number : 0;
};

const normalizeSituation = (value: unknown) => {
  const safeValue = typeof value === 'string' || typeof value === 'number' ? String(value) : '';
  const normalized = safeValue.trim().toLowerCase();

  if (normalized === 'crítico' || normalized === 'critico') return 'crítico';
  if (normalized === 'atenção' || normalized === 'atencao') return 'atenção';
  return normalized || '—';
};

function getSituationColor(situation: string) {
  const normalized = normalizeSituation(situation).toLowerCase();
  if (normalized === 'crítico' || normalized === 'critico') return 'text-red-700 bg-red-50 border-red-200';
  if (normalized === 'atenção' || normalized === 'atencao') return 'text-amber-700 bg-amber-50 border-amber-200';
  return 'text-emerald-700 bg-emerald-50 border-emerald-200';
}

type ScoreApiResponse = {
  disponivel: boolean;
  linhas: number;
};

type QueryRow = Record<string, unknown>;

export function AnalyticsPage() {
  const {
    data: kpiData = [] as QueryRow[],
    loading: loadingKpis,
    error: kpiError,
  } = useAnalyticsQuery('kpis') as { data?: QueryRow[]; loading: boolean; error?: string };
  const {
    data: riskData = [] as QueryRow[],
    loading: loadingRisk,
    error: riskError,
  } = useAnalyticsQuery('projetos_risco') as { data?: QueryRow[]; loading: boolean; error?: string };
  const {
    data: peopleData = [] as QueryRow[],
    error: peopleError,
  } = useAnalyticsQuery('pessoas_ociosas') as { data?: QueryRow[]; error?: string };

  const [scoreApi, setScoreApi] = useState<ScoreApiResponse>({ disponivel: false, linhas: 0 });
  const [selectedPersonId, setSelectedPersonId] = useState<string>('');
  const [selectedProjectId, setSelectedProjectId] = useState<string>('');
  const [onboardingHours, setOnboardingHours] = useState<number>(40);

  useEffect(() => {
    let ignore = false;

    fetch('/api/score-estouro')
      .then((response) => response.json())
      .then((next: ScoreApiResponse) => {
        if (!ignore) {
          setScoreApi(next);
        }
      })
      .catch(() => {
        if (!ignore) {
          setScoreApi({ disponivel: false, linhas: 0 });
        }
      });

    return () => {
      ignore = true;
    };
  }, []);

  const kpiRow = useMemo(() => {
    const row = (kpiData ?? [])[0] ?? {};
    return {
      projetos_em_andamento: toNumber(row.projetos_em_andamento),
      projetos_em_risco: toNumber(row.projetos_em_risco),
      projetos_criticos: toNumber(row.projetos_criticos),
      melancias: toNumber(row.melancias),
      valor_estouro_previsto: toNumber(row.valor_estouro_previsto),
      carteira_total: toNumber(row.carteira_total),
      alto_risco_em_30d: toNumber(row.alto_risco_em_30d),
    };
  }, [kpiData]);

  const projectRows = useMemo(
    () =>
      (riskData ?? []).map((row) => ({
        ...row,
        projeto: typeof row.projeto === 'string' || typeof row.projeto === 'number' ? String(row.projeto) : '',
        cliente: typeof row.cliente === 'string' || typeof row.cliente === 'number' ? String(row.cliente) : '—',
        situacao: normalizeSituation(row.situacao),
        spi: toNumber(row.spi),
        cpi: toNumber(row.cpi),
        estouro_previsto: toNumber(row.estouro_previsto),
        atraso_projetado_dias: toNumber(row.atraso_projetado_dias),
        dias_impacto_falta_sre: toNumber(row.dias_impacto_falta_sre),
        dias_impacto_rotatividade: toNumber(row.dias_impacto_rotatividade),
        farol_do_gerente: typeof row.farol_do_gerente === 'string' || typeof row.farol_do_gerente === 'number' ? String(row.farol_do_gerente) : '—',
        farol_calculado: typeof row.farol_calculado === 'string' || typeof row.farol_calculado === 'number' ? String(row.farol_calculado) : '—',
        melancia: Boolean(row.melancia),
      })),
    [riskData],
  );

  const personRows = useMemo(
    () =>
      (peopleData ?? []).map((row) => ({
        ...row,
        pessoa_id: typeof row.pessoa_id === 'string' || typeof row.pessoa_id === 'number' ? String(row.pessoa_id) : '',
        nome: typeof row.nome === 'string' || typeof row.nome === 'number' ? String(row.nome) : '—',
        papel: typeof row.papel === 'string' || typeof row.papel === 'number' ? String(row.papel) : '—',
        custo_hora: toNumber(row.custo_hora),
        horas_ociosas_media_semana: toNumber(row.horas_ociosas_media_semana),
        custo_ocioso_medio_semana: toNumber(row.custo_ocioso_medio_semana),
      })),
    [peopleData],
  );

  const availableProjects = projectRows.filter((project) => project.situacao === 'crítico' || project.situacao === 'atenção');

  const selectedProject = availableProjects.find((project) => project.projeto === selectedProjectId) ?? availableProjects[0] ?? null;
  const selectedPerson = personRows.find((person) => person.pessoa_id === selectedPersonId) ?? personRows[0] ?? null;

  const hoursInMonth = selectedPerson ? selectedPerson.horas_ociosas_media_semana * 4 : 0;
  const idleCost = selectedPerson ? selectedPerson.horas_ociosas_media_semana * 4 * selectedPerson.custo_hora : 0;
  const scheduleRecoveredDays = selectedProject
    ? ((selectedProject.dias_impacto_falta_sre || selectedProject.dias_impacto_rotatividade || 0) / 90) * 30
    : 0;
  const mobilizationCost = selectedPerson ? onboardingHours * selectedPerson.custo_hora : 0;
  const balance = idleCost - mobilizationCost;

  const uiError = kpiError ?? riskError ?? peopleError;

  return (
    <div className="space-y-6 w-full max-w-7xl mx-auto">
      <div className="flex items-center justify-between gap-4 flex-wrap">
        <div>
          <h2 className="text-2xl font-bold text-foreground">Projetos em risco</h2>
          <p className="text-sm text-muted-foreground">Carteira de projetos em andamento e mobilização de recursos.</p>
        </div>
        {scoreApi.disponivel && <span className="rounded-full border border-emerald-200 bg-emerald-50 px-3 py-1 text-xs font-medium text-emerald-700">Score disponível</span>}
      </div>

      {uiError && <div className="rounded-md border border-red-200 bg-red-50 px-4 py-3 text-sm text-red-700">Erro ao consultar os dados do warehouse.</div>}

      <div className="grid grid-cols-1 md:grid-cols-2 xl:grid-cols-4 gap-4">
        <Card>
          <CardHeader>
            <CardTitle>Em risco</CardTitle>
          </CardHeader>
          <CardContent>
            {loadingKpis ? <Skeleton className="h-8 w-20" /> : <div className="text-3xl font-bold">{kpiRow.projetos_em_risco}</div>}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Estouro previsto</CardTitle>
          </CardHeader>
          <CardContent>
            {loadingKpis ? <Skeleton className="h-8 w-24" /> : <div className="text-3xl font-bold">{currency.format(kpiRow.valor_estouro_previsto)}</div>}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Carteira</CardTitle>
          </CardHeader>
          <CardContent>
            {loadingKpis ? <Skeleton className="h-8 w-24" /> : <div className="text-3xl font-bold">{currency.format(kpiRow.carteira_total)}</div>}
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Alto risco em 30 dias</CardTitle>
          </CardHeader>
          <CardContent>
            {loadingKpis ? <Skeleton className="h-8 w-24" /> : <div className="text-3xl font-bold">{kpiRow.alto_risco_em_30d}</div>}
          </CardContent>
        </Card>
      </div>

      <Card>
        <CardHeader>
          <CardTitle>Projetos em atenção e crítico</CardTitle>
        </CardHeader>
        <CardContent>
          <div className="overflow-x-auto">
            <table className="min-w-full text-left text-sm">
              <thead>
                <tr className="border-b text-muted-foreground">
                  <th className="px-2 py-3 font-medium">Projeto</th>
                  <th className="px-2 py-3 font-medium">Cliente</th>
                  <th className="px-2 py-3 font-medium">Situação</th>
                  <th className="px-2 py-3 font-medium">SPI</th>
                  <th className="px-2 py-3 font-medium">CPI</th>
                  <th className="px-2 py-3 font-medium">Estouro</th>
                  <th className="px-2 py-3 font-medium">Atraso</th>
                  <th className="px-2 py-3 font-medium">Farol</th>
                  <th className="px-2 py-3 font-medium">P(estouro)</th>
                </tr>
              </thead>
              <tbody>
                {loadingRisk ? (
                  <tr>
                    <td colSpan={9} className="px-2 py-4">
                      <Skeleton className="h-10 w-full" />
                    </td>
                  </tr>
                ) : (
                  projectRows.map((project) => (
                    <tr key={project.projeto} className="border-b last:border-0">
                      <td className="px-2 py-3 font-medium">{project.projeto}{project.melancia ? ' 🍉' : ''}</td>
                      <td className="px-2 py-3">{project.cliente}</td>
                      <td className="px-2 py-3">
                        <span className={`inline-flex rounded-full border px-2 py-1 text-xs font-medium ${getSituationColor(project.situacao)}`}>
                          {project.situacao}
                        </span>
                      </td>
                      <td className="px-2 py-3">{numberFmt.format(project.spi)}</td>
                      <td className="px-2 py-3">{numberFmt.format(project.cpi)}</td>
                      <td className="px-2 py-3">{currency.format(project.estouro_previsto)}</td>
                      <td className="px-2 py-3">{project.atraso_projetado_dias} dias</td>
                      <td className="px-2 py-3">{project.farol_do_gerente} / {project.farol_calculado}</td>
                      <td className="px-2 py-3 text-muted-foreground">{scoreApi.disponivel ? '—' : '—'}</td>
                    </tr>
                  ))
                )}
              </tbody>
            </table>
          </div>
        </CardContent>
      </Card>

      <div className="grid grid-cols-1 xl:grid-cols-2 gap-6">
        <Card>
          <CardHeader>
            <CardTitle>Simulador de mobilização</CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <div className="grid gap-4 md:grid-cols-2">
              <div className="space-y-2">
                <Label>Pessoa ociosa</Label>
                <Select value={selectedPerson?.pessoa_id ?? personRows[0]?.pessoa_id ?? ''} onValueChange={setSelectedPersonId}>
                  <SelectTrigger>
                    <SelectValue placeholder="Selecione" />
                  </SelectTrigger>
                  <SelectContent>
                    {personRows.map((person) => (
                      <SelectItem key={person.pessoa_id} value={person.pessoa_id}>
                        {person.nome} · {person.papel}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>

              <div className="space-y-2">
                <Label>Projeto alvo</Label>
                <Select value={selectedProject?.projeto ?? availableProjects[0]?.projeto ?? ''} onValueChange={setSelectedProjectId}>
                  <SelectTrigger>
                    <SelectValue placeholder="Selecione" />
                  </SelectTrigger>
                  <SelectContent>
                    {availableProjects.map((project) => (
                      <SelectItem key={project.projeto} value={project.projeto}>
                        {project.projeto} · {project.cliente}
                      </SelectItem>
                    ))}
                  </SelectContent>
                </Select>
              </div>
            </div>

            <div className="space-y-2">
              <Label htmlFor="onboarding-hours">Horas de onboarding</Label>
              <input
                id="onboarding-hours"
                type="number"
                min={0}
                step={5}
                value={onboardingHours}
                onChange={(event) => setOnboardingHours(Number(event.target.value) || 0)}
                className="flex h-10 w-full rounded-md border bg-background px-3 py-2 text-sm"
              />
            </div>

            <div className="grid grid-cols-2 gap-3 text-sm">
              <div className="rounded-md border bg-muted/30 p-3">
                <div className="text-muted-foreground">Horas no mês</div>
                <div className="text-lg font-semibold">{numberFmt.format(hoursInMonth)}h</div>
              </div>
              <div className="rounded-md border bg-muted/30 p-3">
                <div className="text-muted-foreground">Ociosidade paga</div>
                <div className="text-lg font-semibold">{currency.format(idleCost)}</div>
              </div>
              <div className="rounded-md border bg-muted/30 p-3">
                <div className="text-muted-foreground">Dias recuperados</div>
                <div className="text-lg font-semibold">{numberFmt.format(scheduleRecoveredDays)} dias</div>
              </div>
              <div className="rounded-md border bg-muted/30 p-3">
                <div className="text-muted-foreground">Mobilização</div>
                <div className="text-lg font-semibold">{currency.format(mobilizationCost)}</div>
              </div>
            </div>

            <div className="rounded-md border border-emerald-200 bg-emerald-50 p-3 text-sm text-emerald-900">
              <div className="font-semibold">Saldo estimado</div>
              <div className="mt-1 text-2xl font-bold">{currency.format(balance)}</div>
            </div>

            <details className="rounded-md border p-3 text-sm text-muted-foreground">
              <summary className="cursor-pointer font-medium text-foreground">Como a conta é calculada</summary>
              <div className="mt-2 space-y-2">
                <p>Horas de ociosidade no mês = média semanal de horas paradas × 4 semanas.</p>
                <p>Ociosidade paga = horas no mês × custo por hora.</p>
                <p>Dias recuperados = (dias de impacto da causa nos últimos 90 dias ÷ 90) × 30.</p>
                <p>Mobilização = horas de onboarding × custo por hora.</p>
                <p>Saldo = ociosidade paga − mobilização.</p>
              </div>
            </details>
          </CardContent>
        </Card>

        <Card>
          <CardHeader>
            <CardTitle>Perguntar ao Genie</CardTitle>
          </CardHeader>
          <CardContent className="p-0">
            <div className="h-[480px] w-full">
              <GenieChat alias="default" />
            </div>
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
