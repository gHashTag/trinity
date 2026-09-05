import { postsIndex } from './index'
import { body as body_queen_foundation_snapshot_contract, ruBody as ruBody_queen_foundation_snapshot_contract } from './bodies/queen-foundation-snapshot-contract'
import { body as body_clara_proposal_submitted_not_reviewed, ruBody as ruBody_clara_proposal_submitted_not_reviewed } from './bodies/clara-proposal-submitted-not-reviewed'
import { body as body_tri_claw_an_agent_you_can_audit, ruBody as ruBody_tri_claw_an_agent_you_can_audit } from './bodies/tri-claw-an-agent-you-can-audit'
import { body as body_a_health_snapshot_changed_its_denominator, ruBody as ruBody_a_health_snapshot_changed_its_denominator } from './bodies/a-health-snapshot-changed-its-denominator'
import type { Post, PostBody } from './types'
import { body as body_the_only_stable_speed_belonged_to_the_tool, ruBody as ruBody_the_only_stable_speed_belonged_to_the_tool } from './bodies/the-only-stable-speed-belonged-to-the-tool'
import { body as body_queen_review_lifecycle_queues, ruBody as ruBody_queen_review_lifecycle_queues } from './bodies/queen-review-lifecycle-queues'
import { body as body_physical_width_changed_the_question, ruBody as ruBody_physical_width_changed_the_question } from './bodies/physical-width-changed-the-question'
import { body as body_nobodys_example, ruBody as ruBody_nobodys_example } from './bodies/nobodys-example'
import { body as body_the_silence_was_a_saturated_readout, ruBody as ruBody_the_silence_was_a_saturated_readout } from './bodies/the-silence-was-a-saturated-readout'
import { body as body_twenty_merged_in_three_days, ruBody as ruBody_twenty_merged_in_three_days } from './bodies/twenty-merged-in-three-days'
import { body as body_energy_asymmetry_activations, ruBody as ruBody_energy_asymmetry_activations } from './bodies/energy-asymmetry-activations'
import { body as body_phi_identity_machine_checked, ruBody as ruBody_phi_identity_machine_checked } from './bodies/phi-identity-machine-checked'
import { body as body_readout_that_cannot_be_misread, ruBody as ruBody_readout_that_cannot_be_misread } from './bodies/readout-that-cannot-be-misread'
import { body as body_frame_length_margin_law, ruBody as ruBody_frame_length_margin_law } from './bodies/frame-length-margin-law'
import { body as body_fifteen_merged_nine_credited, ruBody as ruBody_fifteen_merged_nine_credited } from './bodies/fifteen-merged-nine-credited'
import { body as body_context_length_resonance_not_power_law, ruBody as ruBody_context_length_resonance_not_power_law } from './bodies/context-length-resonance-not-power-law'
import { body as body_eight_theorems_audited, ruBody as ruBody_eight_theorems_audited } from './bodies/eight-theorems-audited'
import { body as body_twenty_three_reference_models, ruBody as ruBody_twenty_three_reference_models } from './bodies/twenty-three-reference-models'
import { body as body_the_experiment_that_could_not_answer, ruBody as ruBody_the_experiment_that_could_not_answer } from './bodies/the-experiment-that-could-not-answer'
import { body as body_the_auditor_made_the_mistake_it_audits, ruBody as ruBody_the_auditor_made_the_mistake_it_audits } from './bodies/the-auditor-made-the-mistake-it-audits'
import { body as body_equal_stored_width_removed_an_accuracy_lead, ruBody as ruBody_equal_stored_width_removed_an_accuracy_lead } from './bodies/equal-stored-width-removed-an-accuracy-lead'
import { body as body_thirty_epochs_exposed_a_failure_rate_blind_spot, ruBody as ruBody_thirty_epochs_exposed_a_failure_rate_blind_spot } from './bodies/thirty-epochs-exposed-a-failure-rate-blind-spot'
import { body as body_receipts_and_seals_over_radio, ruBody as ruBody_receipts_and_seals_over_radio } from './bodies/receipts-and-seals-over-radio'
import { body as body_phi_is_a_scale_not_information, ruBody as ruBody_phi_is_a_scale_not_information } from './bodies/phi-is-a-scale-not-information'
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
import { body as body_two_bitstreams_one_bit_apart, ruBody as ruBody_two_bitstreams_one_bit_apart } from './bodies/two-bitstreams-one-bit-apart'
import { body as body_a_multiplicity_correction_changed_the_deployment_reading, ruBody as ruBody_a_multiplicity_correction_changed_the_deployment_reading } from './bodies/a-multiplicity-correction-changed-the-deployment-reading'
import { body as body_the_full_adder_made_the_cost_claim_comparable, ruBody as ruBody_the_full_adder_made_the_cost_claim_comparable } from './bodies/the-full-adder-made-the-cost-claim-comparable'
import { body as body_the_tail_that_had_never_run, ruBody as ruBody_the_tail_that_had_never_run } from './bodies/the-tail-that-had-never-run'
import { body as body_fourteen_rows_agreed_one_did_not, ruBody as ruBody_fourteen_rows_agreed_one_did_not } from './bodies/fourteen-rows-agreed-one-did-not'
import { body as body_a_clean_merge_is_not_a_semantic_no_op, ruBody as ruBody_a_clean_merge_is_not_a_semantic_no_op } from './bodies/a-clean-merge-is-not-a-semantic-no-op'
import { body as body_formal_was_green_and_had_never_run_a_solver, ruBody as ruBody_formal_was_green_and_had_never_run_a_solver } from './bodies/formal-was-green-and-had-never-run-a-solver'

import { body as body_the_required_check_was_an_echo, ruBody as ruBody_the_required_check_was_an_echo } from './bodies/the-required-check-was-an-echo'
import { body as body_the_gate_was_right_and_nothing_stopped, ruBody as ruBody_the_gate_was_right_and_nothing_stopped } from './bodies/the-gate-was-right-and-nothing-stopped'
import { body as body_the_ratchet_counted_a_total_as_an_error, ruBody as ruBody_the_ratchet_counted_a_total_as_an_error } from './bodies/the-ratchet-counted-a-total-as-an-error'
import { body as body_four_hundred_and_twelve_tests_that_were_sentences, ruBody as ruBody_four_hundred_and_twelve_tests_that_were_sentences } from './bodies/four-hundred-and-twelve-tests-that-were-sentences'
import { body as body_ternary_won_the_wire_not_the_gate, ruBody as ruBody_ternary_won_the_wire_not_the_gate } from './bodies/ternary-won-the-wire-not-the-gate'

import { body as body_the_control_that_could_not_fail, ruBody as ruBody_the_control_that_could_not_fail } from './bodies/the-control-that-could-not-fail'

import { body as body_the_scanner_scored_what_it_could_not_see, ruBody as ruBody_the_scanner_scored_what_it_could_not_see } from './bodies/the-scanner-scored-what-it-could-not-see'

import { body as body_i_wrote_the_post_then_did_the_thing, ruBody as ruBody_i_wrote_the_post_then_did_the_thing } from './bodies/i-wrote-the-post-then-did-the-thing'
import { body as body_real_value_in_integer_container, ruBody as ruBody_real_value_in_integer_container } from './bodies/real-value-in-integer-container'
import { body as body_one_commit_nine_workflow_outcomes, ruBody as ruBody_one_commit_nine_workflow_outcomes } from './bodies/one-commit-nine-workflow-outcomes'

const bodies: Record<string, PostBody> = {
  'queen-foundation-snapshot-contract': { body: body_queen_foundation_snapshot_contract, ruBody: ruBody_queen_foundation_snapshot_contract },
  'clara-proposal-submitted-not-reviewed': { body: body_clara_proposal_submitted_not_reviewed, ruBody: ruBody_clara_proposal_submitted_not_reviewed },
  'queen-review-lifecycle-queues': { body: body_queen_review_lifecycle_queues, ruBody: ruBody_queen_review_lifecycle_queues },
  'one-commit-nine-workflow-outcomes': { body: body_one_commit_nine_workflow_outcomes, ruBody: ruBody_one_commit_nine_workflow_outcomes },
  'real-value-in-integer-container': { body: body_real_value_in_integer_container, ruBody: ruBody_real_value_in_integer_container },
  'physical-width-changed-the-question': { body: body_physical_width_changed_the_question, ruBody: ruBody_physical_width_changed_the_question },
  'nobodys-example': { body: body_nobodys_example, ruBody: ruBody_nobodys_example },
  'the-silence-was-a-saturated-readout': { body: body_the_silence_was_a_saturated_readout, ruBody: ruBody_the_silence_was_a_saturated_readout },
  'twenty-merged-in-three-days': { body: body_twenty_merged_in_three_days, ruBody: ruBody_twenty_merged_in_three_days },
  'energy-asymmetry-activations': { body: body_energy_asymmetry_activations, ruBody: ruBody_energy_asymmetry_activations },
  'phi-identity-machine-checked': { body: body_phi_identity_machine_checked, ruBody: ruBody_phi_identity_machine_checked },
  'readout-that-cannot-be-misread': { body: body_readout_that_cannot_be_misread, ruBody: ruBody_readout_that_cannot_be_misread },
  'frame-length-margin-law': { body: body_frame_length_margin_law, ruBody: ruBody_frame_length_margin_law },
  'fifteen-merged-nine-credited': { body: body_fifteen_merged_nine_credited, ruBody: ruBody_fifteen_merged_nine_credited },
  'context-length-resonance-not-power-law': { body: body_context_length_resonance_not_power_law, ruBody: ruBody_context_length_resonance_not_power_law },
  'eight-theorems-audited': { body: body_eight_theorems_audited, ruBody: ruBody_eight_theorems_audited },
  'twenty-three-reference-models': { body: body_twenty_three_reference_models, ruBody: ruBody_twenty_three_reference_models },
  'the-experiment-that-could-not-answer': { body: body_the_experiment_that_could_not_answer, ruBody: ruBody_the_experiment_that_could_not_answer },
  'the-auditor-made-the-mistake-it-audits': { body: body_the_auditor_made_the_mistake_it_audits, ruBody: ruBody_the_auditor_made_the_mistake_it_audits },
  'i-wrote-the-post-then-did-the-thing': { body: body_i_wrote_the_post_then_did_the_thing, ruBody: ruBody_i_wrote_the_post_then_did_the_thing },
  'the-scanner-scored-what-it-could-not-see': { body: body_the_scanner_scored_what_it_could_not_see, ruBody: ruBody_the_scanner_scored_what_it_could_not_see },
  'the-control-that-could-not-fail': { body: body_the_control_that_could_not_fail, ruBody: ruBody_the_control_that_could_not_fail },
  'ternary-won-the-wire-not-the-gate': { body: body_ternary_won_the_wire_not_the_gate, ruBody: ruBody_ternary_won_the_wire_not_the_gate },
  'the-required-check-was-an-echo': { body: body_the_required_check_was_an_echo, ruBody: ruBody_the_required_check_was_an_echo },
  'the-gate-was-right-and-nothing-stopped': { body: body_the_gate_was_right_and_nothing_stopped, ruBody: ruBody_the_gate_was_right_and_nothing_stopped },
  'the-ratchet-counted-a-total-as-an-error': { body: body_the_ratchet_counted_a_total_as_an_error, ruBody: ruBody_the_ratchet_counted_a_total_as_an_error },
  'four-hundred-and-twelve-tests-that-were-sentences': { body: body_four_hundred_and_twelve_tests_that_were_sentences, ruBody: ruBody_four_hundred_and_twelve_tests_that_were_sentences },
  'equal-stored-width-removed-an-accuracy-lead': { body: body_equal_stored_width_removed_an_accuracy_lead, ruBody: ruBody_equal_stored_width_removed_an_accuracy_lead },
  'thirty-epochs-exposed-a-failure-rate-blind-spot': { body: body_thirty_epochs_exposed_a_failure_rate_blind_spot, ruBody: ruBody_thirty_epochs_exposed_a_failure_rate_blind_spot },
  'formal-was-green-and-had-never-run-a-solver': { body: body_formal_was_green_and_had_never_run_a_solver, ruBody: ruBody_formal_was_green_and_had_never_run_a_solver },
  'fourteen-rows-agreed-one-did-not': { body: body_fourteen_rows_agreed_one_did_not, ruBody: ruBody_fourteen_rows_agreed_one_did_not },
  'a-clean-merge-is-not-a-semantic-no-op': { body: body_a_clean_merge_is_not_a_semantic_no_op, ruBody: ruBody_a_clean_merge_is_not_a_semantic_no_op },
  'the-tail-that-had-never-run': { body: body_the_tail_that_had_never_run, ruBody: ruBody_the_tail_that_had_never_run },
  'the-full-adder-made-the-cost-claim-comparable': { body: body_the_full_adder_made_the_cost_claim_comparable, ruBody: ruBody_the_full_adder_made_the_cost_claim_comparable },
  'phi-is-a-scale-not-information': { body: body_phi_is_a_scale_not_information, ruBody: ruBody_phi_is_a_scale_not_information },
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
  'tri-claw-an-agent-you-can-audit': { body: body_tri_claw_an_agent_you_can_audit, ruBody: ruBody_tri_claw_an_agent_you_can_audit },
  'receipts-and-seals-over-radio': { body: body_receipts_and_seals_over_radio, ruBody: ruBody_receipts_and_seals_over_radio },
  'open-gigabit-ethernet-artix7': { body: body_open_gigabit_ethernet_artix7, ruBody: ruBody_open_gigabit_ethernet_artix7 },
  'two-bitstreams-one-bit-apart': { body: body_two_bitstreams_one_bit_apart, ruBody: ruBody_two_bitstreams_one_bit_apart },
  'a-multiplicity-correction-changed-the-deployment-reading': { body: body_a_multiplicity_correction_changed_the_deployment_reading, ruBody: ruBody_a_multiplicity_correction_changed_the_deployment_reading },
  'the-only-stable-speed-belonged-to-the-tool': { body: body_the_only_stable_speed_belonged_to_the_tool, ruBody: ruBody_the_only_stable_speed_belonged_to_the_tool },
}

export type { Block, Post } from './types'

export const posts: Post[] = postsIndex.map((meta) => {
  if (!meta.tags.length) throw new Error(`Missing mandatory blog tags: ${meta.slug}`)
  const body = bodies[meta.slug]
  if (!body) throw new Error(`Missing blog body: ${meta.slug}`)
  return { ...meta, body: body.body, ru: meta.ru && body.ruBody ? { ...meta.ru, body: body.ruBody } : undefined }
})

export const publishedPosts = () => posts.filter((p) => p.published)
export const postBySlug = (slug: string) => posts.find((p) => p.slug === slug)
