import { Pool } from "pg";

export class MachineService {
  constructor(private readonly db: Pool) {}

  async getMachines(filters: { category?: string; equipment?: string; brand?: string } = {}) {
    const conditions: string[] = [];
    const params: unknown[] = [];

    if (filters.category) {
      params.push(filters.category);
      conditions.push(`m.category = $${params.length}`);
    }
    if (filters.equipment) {
      params.push(filters.equipment);
      conditions.push(`m.equipment_type = $${params.length}`);
    }
    if (filters.brand) {
      params.push(filters.brand);
      conditions.push(
        `EXISTS (SELECT 1 FROM machine_models mm JOIN machine_brands mb ON mb.id = mm.brand_id WHERE mm.machine_id = m.id AND mb.slug = $${params.length})`
      );
    }

    const where = conditions.length ? `WHERE ${conditions.join(" AND ")}` : "";
    const { rows } = await this.db.query(
      `SELECT id, name, slug, alternate_names, category, equipment_type,
              primary_muscles, secondary_muscles, movement_pattern, description, image_url, tags
       FROM machines
       ${where}
       ORDER BY category, name`,
      params
    );
    return rows;
  }

  async getMachinesByCategory() {
    const { rows } = await this.db.query(
      `SELECT category, json_agg(json_build_object(
        'id', id, 'name', name, 'slug', slug,
        'equipment_type', equipment_type,
        'primary_muscles', primary_muscles
       ) ORDER BY name) AS machines
       FROM machines
       GROUP BY category
       ORDER BY category`
    );
    return rows.reduce<Record<string, unknown[]>>((acc, row) => {
      acc[row.category] = row.machines;
      return acc;
    }, {});
  }

  async getMachineDetail(slug: string) {
    const { rows: machines } = await this.db.query(
      `SELECT id, name, slug, alternate_names, category, sub_category, equipment_type,
              primary_muscles, secondary_muscles, movement_pattern, description, image_url, tags
       FROM machines WHERE slug = $1`,
      [slug]
    );
    if (!machines.length) return null;
    const machine = machines[0];

    const [{ rows: models }, { rows: exercises }, { rows: substitutions }] = await Promise.all([
      this.db.query(
        `SELECT mm.id, mm.machine_id, mm.brand_id, mb.name AS brand_name,
                mm.model_name, mm.equipment_type, mm.setup_instructions,
                mm.adjustment_notes, mm.usage_steps, mm.form_cues,
                mm.common_mistakes, mm.safety_notes, mm.beginner_tips,
                mm.advanced_tips, mm.rep_range_rec, mm.notes
         FROM machine_models mm
         JOIN machine_brands mb ON mb.id = mm.brand_id
         WHERE mm.machine_id = $1
         ORDER BY mb.name`,
        [machine.id]
      ),
      this.db.query(
        `SELECT exercise_name, exercise_id::text, notes
         FROM machine_exercises
         WHERE machine_id = $1`,
        [machine.id]
      ),
      this.db.query(
        `SELECT ms.substitution_type, ms.notes,
                sm.name AS substitute_machine_name, sm.slug AS substitute_machine_slug,
                ms.substitute_exercise_id::text
         FROM machine_substitutions ms
         LEFT JOIN machines sm ON sm.id = ms.substitute_machine_id
         WHERE ms.machine_id = $1`,
        [machine.id]
      ),
    ]);

    return { ...machine, models, exercises, substitutions };
  }

  async getBrands() {
    const { rows } = await this.db.query(
      `SELECT id, name, slug, website_url FROM machine_brands ORDER BY name`
    );
    return rows;
  }

  async getMachinesByBrand() {
    const { rows } = await this.db.query<{
      brand_id: string;
      brand_name: string;
      brand_slug: string;
      brand_website: string | null;
      machines: unknown[];
    }>(
      `SELECT
         b.id::text   AS brand_id,
         b.name       AS brand_name,
         b.slug       AS brand_slug,
         b.website_url AS brand_website,
         json_agg(DISTINCT jsonb_build_object(
           'id', m.id::text,
           'name', m.name,
           'slug', m.slug,
           'category', m.category,
           'equipment_type', m.equipment_type,
           'primary_muscles', m.primary_muscles,
           'image_url', m.image_url
         )) AS machines
       FROM machine_brands b
       JOIN machine_models mm ON mm.brand_id = b.id
       JOIN machines m        ON m.id = mm.machine_id
       GROUP BY b.id, b.name, b.slug, b.website_url
       ORDER BY b.name`
    );
    return rows.map((r) => ({
      brand: {
        id: r.brand_id,
        name: r.brand_name,
        slug: r.brand_slug,
        website_url: r.brand_website,
      },
      machines: r.machines,
    }));
  }

  async searchMachines(query: string) {
    const tsquery = query
      .trim()
      .split(/\s+/)
      .filter(Boolean)
      .map((w) => w + ":*")
      .join(" & ");

    const { rows } = await this.db.query(
      `SELECT id, name, slug, category, equipment_type, primary_muscles, image_url
       FROM machines
       WHERE search_vector @@ to_tsquery('english', $1)
       ORDER BY name
       LIMIT 20`,
      [tsquery]
    );
    return rows;
  }
}
