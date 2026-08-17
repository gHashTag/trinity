import { postsIndex } from './index'
import { body as body_a_health_snapshot_changed_its_denominator, ruBody as ruBody_a_health_snapshot_changed_its_denominator } from './bodies/a-health-snapshot-changed-its-denominator'
import type { Post, PostBody } from './types'
import { body as body_an_inert_filter_is_safest_until_it_works, ruBody as ruBody_an_inert_filter_is_safest_until_it_works } from './bodies/an-inert-filter-is-safest-until-it-works'
import { body as body_a_gate_that_rejected_its_own_users, ruBody as ruBody_a_gate_that_rejected_its_own_users } from './bodies/a-gate-that-rejected-its-own-users'
import { body as body_a_broken_reference_looks_exactly_like_broken_code, ruBody as ruBody_a_broken_reference_looks_exactly_like_broken_code } from './bodies/a-broken-reference-looks-exactly-like-broken-code'
import { body as body_a_red_gate_was_missing_its_input, ruBody as ruBody_a_red_gate_was_missing_its_input } from './bodies/a-red-gate-was-missing-its-input'
import { body as body_five_reasons_the_build_was_red, ruBody as ruBody_five_reasons_the_build_was_red } from './bodies/five-reasons-the-build-was-red'
import { body as body_the_generated_file_was_three_years_old, ruBody as ruBody_the_generated_file_was_three_years_old } from './bodies/the-generated-file-was-three-years-old'
import { body as body_half_the_build_is_bitstream_generation, ruBody as ruBody_half_the_build_is_bitstream_generation } from './bodies/half-the-build-is-bitstream-generation'
import { body as body_the_search_space_erased_a_significance_claim, ruBody as ruBody_the_search_space_erased_a_significance_claim } from './bodies/the-search-space-erased-a-significance-claim'
import { body as body_six_and_a_half_years_in_a_discarded_return_value, ruBody as ruBody_six_and_a_half_years_in_a_discarded_return_value } from './bodies/six-and-a-half-years-in-a-discarded-return-value'
import { body as body_a_correct_gate_with_a_manual_remedy, ruBody as ruBody_a_correct_gate_with_a_manual_remedy } from './bodies/a-correct-gate-with-a-manual-remedy'
import { body as body_eleven_verdicts_were_windows_not_checkpoints, ruBody as ruBody_eleven_verdicts_were_windows_not_checkpoints } from './bodies/eleven-verdicts-were-windows-not-checkpoints'
import { body as body_each_half_imported_the_other, ruBody as ruBody_each_half_imported_the_other } from './bodies/each-half-imported-the-other'
import { body as body_a_suite_that_runs_nothing_exits_zero, ruBody as ruBody_a_suite_that_runs_nothing_exits_zero } from './bodies/a-suite-that-runs-nothing-exits-zero'
import { body as body_a_repair_reaches_only_the_copy_it_lands_in, ruBody as ruBody_a_repair_reaches_only_the_copy_it_lands_in } from './bodies/a-repair-reaches-only-the-copy-it-lands-in'
import { body as body_green_ci_does_not_mean_usable, ruBody as ruBody_green_ci_does_not_mean_usable } from './bodies/green-ci-does-not-mean-usable'
import { body as body_scale_field_width_already_published, ruBody as ruBody_scale_field_width_already_published } from './bodies/scale-field-width-already-published'
import { body as body_open_gigabit_ethernet_artix7, ruBody as ruBody_open_gigabit_ethernet_artix7 } from './bodies/open-gigabit-ethernet-artix7'
import { body as body_a_multiplicity_correction_changed_the_deployment_reading, ruBody as ruBody_a_multiplicity_correction_changed_the_deployment_reading } from './bodies/a-multiplicity-correction-changed-the-deployment-reading'

const bodies: Record<string, PostBody> = {
  'an-inert-filter-is-safest-until-it-works': { body: body_an_inert_filter_is_safest_until_it_works, ruBody: ruBody_an_inert_filter_is_safest_until_it_works },
  'a-gate-that-rejected-its-own-users': { body: body_a_gate_that_rejected_its_own_users, ruBody: ruBody_a_gate_that_rejected_its_own_users },
  'a-health-snapshot-changed-its-denominator': { body: body_a_health_snapshot_changed_its_denominator, ruBody: ruBody_a_health_snapshot_changed_its_denominator },
  'a-broken-reference-looks-exactly-like-broken-code': { body: body_a_broken_reference_looks_exactly_like_broken_code, ruBody: ruBody_a_broken_reference_looks_exactly_like_broken_code },
  'a-red-gate-was-missing-its-input': { body: body_a_red_gate_was_missing_its_input, ruBody: ruBody_a_red_gate_was_missing_its_input },
  'five-reasons-the-build-was-red': { body: body_five_reasons_the_build_was_red, ruBody: ruBody_five_reasons_the_build_was_red },
  'the-generated-file-was-three-years-old': { body: body_the_generated_file_was_three_years_old, ruBody: ruBody_the_generated_file_was_three_years_old },
  'half-the-build-is-bitstream-generation': { body: body_half_the_build_is_bitstream_generation, ruBody: ruBody_half_the_build_is_bitstream_generation },
  'the-search-space-erased-a-significance-claim': { body: body_the_search_space_erased_a_significance_claim, ruBody: ruBody_the_search_space_erased_a_significance_claim },
  'six-and-a-half-years-in-a-discarded-return-value': { body: body_six_and_a_half_years_in_a_discarded_return_value, ruBody: ruBody_six_and_a_half_years_in_a_discarded_return_value },
  'a-correct-gate-with-a-manual-remedy': { body: body_a_correct_gate_with_a_manual_remedy, ruBody: ruBody_a_correct_gate_with_a_manual_remedy },
  'eleven-verdicts-were-windows-not-checkpoints': { body: body_eleven_verdicts_were_windows_not_checkpoints, ruBody: ruBody_eleven_verdicts_were_windows_not_checkpoints },
  'each-half-imported-the-other': { body: body_each_half_imported_the_other, ruBody: ruBody_each_half_imported_the_other },
  'a-suite-that-runs-nothing-exits-zero': { body: body_a_suite_that_runs_nothing_exits_zero, ruBody: ruBody_a_suite_that_runs_nothing_exits_zero },
  'a-repair-reaches-only-the-copy-it-lands-in': { body: body_a_repair_reaches_only_the_copy_it_lands_in, ruBody: ruBody_a_repair_reaches_only_the_copy_it_lands_in },
  'green-ci-does-not-mean-usable': { body: body_green_ci_does_not_mean_usable, ruBody: ruBody_green_ci_does_not_mean_usable },
  'scale-field-width-already-published': { body: body_scale_field_width_already_published, ruBody: ruBody_scale_field_width_already_published },
  'open-gigabit-ethernet-artix7': { body: body_open_gigabit_ethernet_artix7, ruBody: ruBody_open_gigabit_ethernet_artix7 },
  'a-multiplicity-correction-changed-the-deployment-reading': { body: body_a_multiplicity_correction_changed_the_deployment_reading, ruBody: ruBody_a_multiplicity_correction_changed_the_deployment_reading },
}

export type { Block, Post } from './types'

export const posts: Post[] = postsIndex.map((meta) => {
  const body = bodies[meta.slug]
  if (!body) throw new Error(`Missing blog body: ${meta.slug}`)
  return { ...meta, body: body.body, ru: meta.ru && body.ruBody ? { ...meta.ru, body: body.ruBody } : undefined }
})

export const publishedPosts = () => posts.filter((p) => p.published)
export const postBySlug = (slug: string) => posts.find((p) => p.slug === slug)
