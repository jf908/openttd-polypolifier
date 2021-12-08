require("locations.nut")
require("module.nut")
require("setting_names.nut")
require("util.nut")

class RobinHoodScheme extends Module
{
	pot = null;
	company_list = null;
	robin_hood_basic_rate = 0.10;

	constructor(pot, companies)
	{
		::Module.constructor();
		this.pot = pot;
		this.company_list = companies;
	}

	function Refresh()
	{
		robin_hood_basic_rate = GetSetting(::ROBIN_HOOD_RATE);
	}

	function OnQuarter(args)
	{
		GSLog.Error("Executing Robin Hood scheme");
		local quarter = args[0];

		local companies = company_list.GetInfoList();

		local n_companies = companies.len();
		if (n_companies < 2)
		{
			GSLog.Error("Robin hood cannot be operated without distinct benefactors and financiers");
			return;
		}

		local n_taxed_companies = n_companies / 2;
		local n_irrelevant_companies = n_companies - n_taxed_companies;

		foreach (company in companies)
			company.rh_priority <- Priority(company);
		companies.sort(PriorityCompare);

		local beneficiary = null;
		for (local i = 0; i < n_irrelevant_companies; i++)
			if (companies[i].active && companies[i].hq != GSMap.TILE_INVALID)
				beneficiary = companies[i];

		if (!beneficiary)
		{
			GSNews.Create(GSNews.NT_GENERAL, GSText(GSText.RH_CANNOT_OPERATE), GSCompany.COMPANY_INVALID, Locs.NR_CAPITAL, Locs.CAPITAL);
			return;
		}

		local grant = ComputeGrant(beneficiary, companies);

		// Get total value of the companies to tax
		local taxables = companies.slice(-n_taxed_companies);
		local taxables_tot_value = 0;
		foreach (taxable in taxables)
			taxables_tot_value += taxables.q_value;

		// Compute leviable tax
		local leviable = 0;
		foreach (taxable in taxables)
		{
			taxable.rh_levy <- grant * taxable.q_value / taxables_tot_value;
			if (pot.CanMeansTestedlyTax(taxable, taxable.rh_levy))
				leviable += taxable.rh_levy;
		}

		// Levy RH tax
		foreach (taxable in taxables)
			pot.MeansTestedTax(taxable, taxable.rh_levy);

		// Attempt to pay RH grant
		if (pot.Grant(beneficiary, grant))
			GSNews.Create(GSNews.NT_GENERAL, GSText(GSText.ROBIN_HOODED, beneficiary.id, grant), beneficiary.name, GSNews.NR_TILE, beneficiary.hq);
		else
			GSNews.Create(GSNews.NT_GENERAL, GSText(GSText.CANNOT_RH_GRANT_NO_CASH, quarter), GSCompany.COMPANY_INVALID, Locs.NR_CAPITAL, Locs.CAPITAL);
	}

	function ComputeGrant(beneficiary, companies)
	{
		// Assumes that companies is sorted by RH priority
		return Util.Min(
				robin_hood_basic_rate * beneficiary.value,
				robin_hood_basic_rate * (companies[companies.len() / 2].value - beneficiary.value)
				);
	}

	function PriorityCompare(a, b)
	{
		return Util.Compare(a.rh_priority, b.rh_priority);
	}

	function Priority(company)
	{
		return -company.value;
	}
}
